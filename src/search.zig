// SEARCH.ZIG
// ----------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Index = @import("index.zig").Index;
const PostingsHeader = @import("index.zig").PostingsHeader;
const Result = @import("index.zig").Result;
const Term = @import("tokenizer_snippet.zig").Term;
const Token = @import("tokenizer.zig").Token;
const TopK = @import("top_k_heap.zig").TopKHeap;
const query = @import("tokenizer_query.zig");
const Stemmer = @import("stem.zig").Stemmer;
const Snippeter = @import("snippets.zig").Snippeter;
const stem = @import("stem.zig").stem;
const expandQuery = @import("query_expansion.zig").expandQuery;
const config = @import("config.zig");

const c = @import("c");

fn memset(dest: []align(32) u8) void {
    c.memset_avx2(dest.ptr, dest.len);
}

pub const Search = struct {
    const Self = @This();

    index: Index,
    snippets: bool,
    snippeter: Snippeter,
    query: std.ArrayListUnmanaged(query.Term),
    postings: std.ArrayList(PostingsHeader),
    topk: TopK,
    accumulators: []align(32) u16,
    segment_buffer: []align(16) u32,

    pub fn init(io: std.Io, allocator: std.mem.Allocator, dir: std.Io.Dir, index_filename: []const u8) !Self {
        const index_file = try dir.readFileAllocOptions(io, index_filename, allocator, std.Io.Limit.unlimited, .@"16", null);

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

        const accumulators = try allocator.alignedAlloc(u16, std.mem.Alignment.fromByteUnits(32), index.docs.len); 

        return .{
            .index = index,
            .snippets = index.hasSnippets(),
            .snippeter = snippeter,
            .query = try std.ArrayListUnmanaged(query.Term).initCapacity(allocator, config.max_query_terms),
            .postings = try std.ArrayList(PostingsHeader).initCapacity(allocator, config.max_query_terms),
            .topk = TopK.init(accumulators.ptr),
            .accumulators = accumulators,
            .segment_buffer = try allocator.alignedAlloc(u32, .@"16", 128),
        };
    }

    pub fn search(self: *Self, results: []Result, query_raw: []u8) ![]Result {
        self.query.clearRetainingCapacity();

        var tok = query.Parser.init(Stemmer.init(self.index.header.stemmer), &self.query, query_raw);
        tok.parse();

        // TODO reenable once allocation is fixed
        // try expandQuery(allocator, &self.query);

        self.topk.clearRetainingCapacity();
        self.postings.clearRetainingCapacity();

        // TODO fix term negation
        for (self.query.items) |term| {
            const res = self.index.find(term.term);
            if (res.postings != 0) self.postings.appendAssumeCapacity(res);
        }

        // Special case for single term query skipping accumulator reset
        var results_len: usize = 0;
        if (self.postings.items.len == 1) {
            var postings = self.postings.items[0];
            while (true) {
                var last_id: u32 = 0;
                while (postings.len > 0) {
                    // Read block
                    const len = self.index.decompressBlock(&postings, self.segment_buffer, last_id);

                    // Store block
                    for (0..@min(config.max_top_k - results_len, len)) |i| {
                        results_len += 1;
                        results[results_len - 1] = .{ .docid = self.segment_buffer[i], .score = postings.score };
                    }
                    // Successfully found topk
                    if (results_len == config.max_top_k) return results[0..results_len];

                    last_id = self.segment_buffer[len - 1];
                }

                // Next segment
                self.index.nextSegment(&postings);

                // Term exhausted
                if (postings.score == 0) break;
            }
            return results[0..results_len];
        }

        memset(std.mem.sliceAsBytes(self.accumulators));

        // Now process normally
        for (0..self.postings.items.len) |pi| {
            var postings: PostingsHeader = self.postings.items[pi];

            while (postings.score != 0) {
                var last_id: u32 = 0;
                while (postings.len > 0) {
                    // Read block
                    const len = self.index.decompressBlock(&postings, self.segment_buffer, last_id);

                    // Accumulate block
                    for (0..len) |i| {
                        const doc_id = self.segment_buffer[i];
                        const saved = self.accumulators[doc_id];
                        self.accumulators[doc_id] += postings.score;
                        self.topk.insert(doc_id, self.accumulators[doc_id], saved);
                    }

                    last_id = self.segment_buffer[len - 1];
                }
                self.index.nextSegment(&postings);
            }
        }

        return self.topk.results(results);
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
