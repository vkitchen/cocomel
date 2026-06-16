// SEARCH.ZIG
// ----------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Index = @import("index.zig").Index;
const Result = @import("index.zig").Result;
const Term = @import("tokenizer_snippet.zig").Term;
const Token = @import("tokenizer.zig").Token;
const TopK = @import("top_k_insert.zig").TopKInsert;
const query = @import("tokenizer_query.zig");
const Stemmer = @import("stem.zig").Stemmer;
const Snippeter = @import("snippets.zig").Snippeter;
const stem = @import("stem.zig").stem;
const expandQuery = @import("query_expansion.zig").expandQuery;
const config = @import("config.zig");

// ChatGPT generated
pub fn memsetAvx2Aligned(dest: [*]align(32) u8, len: usize, value: u8) void {
    const Vec = @Vector(32, u8);

    const v: Vec = @splat(value);

    var ptr = dest;
    var remaining = len;

    // 256-byte chunks (8 AVX stores)
    while (remaining >= 256) {
        @as(*align(32) Vec, @ptrCast(ptr)).* = v;
        @as(*align(32) Vec, @ptrCast(ptr + 32)).* = v;
        @as(*align(32) Vec, @ptrCast(ptr + 64)).* = v;
        @as(*align(32) Vec, @ptrCast(ptr + 96)).* = v;
        @as(*align(32) Vec, @ptrCast(ptr + 128)).* = v;
        @as(*align(32) Vec, @ptrCast(ptr + 160)).* = v;
        @as(*align(32) Vec, @ptrCast(ptr + 192)).* = v;
        @as(*align(32) Vec, @ptrCast(ptr + 224)).* = v;

        ptr += 256;
        remaining -= 256;
    }

    while (remaining >= 32) {
        @as(*align(32) Vec, @ptrCast(ptr)).* = v;
        ptr += 32;
        remaining -= 32;
    }

    var ptr1: [*]align(1) u8 = ptr;
    while (remaining > 0) {
        ptr1[0] = value;
        ptr1 += 1;
        remaining -= 1;
    }
}

pub const Search = struct {
    const Self = @This();

    index: Index,
    snippets: bool,
    snippeter: Snippeter,
    query: std.ArrayListUnmanaged(query.Term),
    postings: std.ArrayList(u64),
    topk: TopK = .{},
    accumulators: []align(32) u16,

    pub fn init(io: std.Io, allocator: std.mem.Allocator, dir: std.Io.Dir, index_filename: []const u8) !Self {
        const index_file = try dir.readFileAlloc(io, index_filename, allocator, std.Io.Limit.unlimited);

        const index = try Index.init(index_file);

        const snippeter = blk: {
            if (index.hasSnippets()) {
                var max_snippet: u64 = 0;
                var doc_id: u32 = 0;
                while (doc_id < index.docs.len) : (doc_id += 1) {
                    const range = index.snippet(doc_id);
                    const snippet_length = range[1] - range[0];
                    if (snippet_length > max_snippet)
                        max_snippet = snippet_length;
                }

                const snippets_buf = try allocator.alloc(u8, max_snippet);
                const snippets_allocator = std.heap.FixedBufferAllocator.init(snippets_buf);
                const snippets_terms = try std.ArrayListUnmanaged(Term).initCapacity(allocator, index.header.max_doc_length);
                break :blk try Snippeter.init(snippets_allocator, Stemmer.init(index.header.stemmer), index_file, snippets_terms);
            } else {
                break :blk undefined;
            }
        };

        return .{
            .index = index,
            .snippets = index.hasSnippets(),
            .snippeter = snippeter,
            .query = try std.ArrayListUnmanaged(query.Term).initCapacity(allocator, config.max_query_terms),
            .postings = try std.ArrayList(u64).initCapacity(allocator, config.max_query_terms),
            .accumulators = try allocator.alignedAlloc(u16, std.mem.Alignment.fromByteUnits(32), index.docs.len),
        };
    }

    pub fn search(self: *Self, query_raw: []u8) ![]Result {
        self.query.clearRetainingCapacity();

        var tok = query.Parser.init(Stemmer.init(self.index.header.stemmer), &self.query, query_raw);
        tok.parse();

        // TODO reenable once allocation is fixed
        // try expandQuery(allocator, &self.query);

        self.topk.clearRetainingCapacity();
        self.postings.clearRetainingCapacity();

        // TODO fix term negation
        for (self.query.items) |term| {
            const offset = self.index.find(term.term);
            if (offset != 0) self.postings.appendAssumeCapacity(offset);
        }

        // Special case for single term query skipping accumulator reset
        if (self.postings.items.len == 1) {
            while (true) {
                self.postings.items[0] = self.index.processChunkNoAccumulators(self.postings.items[0], &self.topk);
                // Successfully filled topk
                if (self.topk.cap == self.topk.len) break;
                // Term exhausted
                if (self.index.chunkScore(self.postings.items[0]) == 0) break;
            }
            return self.topk.results();
        }

        // @memset(self.accumulators, 0);
        memsetAvx2Aligned(@ptrCast(std.mem.sliceAsBytes(self.accumulators)), self.accumulators.len * 2, 0);

        var max_impact: u16 = 0;
        var max_i: usize = 0;

        // Saturate top-k with highest scoring term
        for (self.postings.items, 0..) |offset, i| {
            if (self.index.chunkScore(offset) > max_impact) {
                max_impact = self.index.chunkScore(offset);
                max_i = i;
            }
        }

        while (true) {
            self.postings.items[max_i] = self.index.processChunkSaturate(self.postings.items[max_i], &self.topk, self.accumulators);
            // Successfully filled topk
            if (self.topk.cap == self.topk.len) break;
            // Term exhausted
            if (self.index.chunkScore(self.postings.items[max_i]) == 0) break;
        }

        // Now process normally
        while (true) {
            max_impact = 0;
            for (self.postings.items, 0..) |offset, i| {
                if (self.index.chunkScore(offset) > max_impact) {
                    max_impact = self.index.chunkScore(offset);
                    max_i = i;
                }
            }

            if (max_impact == 0) break;

            self.postings.items[max_i] = self.index.processChunk(self.postings.items[max_i], &self.topk, self.accumulators);
        }

        return self.topk.sorted();
    }

    pub fn name(self: *const Self, doc_id: u32) [2][]const u8 {
        return self.index.name(doc_id);
    }

    pub fn snippet(self: *Self, doc_id: u32) ![]Term {
        if (!self.snippets)
            return &.{};
        const range = self.index.snippet(doc_id);
        return self.snippeter.snippet(self.query.items, range[0], range[1]);
    }
};
