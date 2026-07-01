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

fn cmpPostings(_: void, a: PostingsHeader, b: PostingsHeader) bool {
    return a.len > b.len;
}

pub const Search = struct {
    const Self = @This();

    index: Index,
    snippets: bool,
    snippeter: Snippeter,
    query: std.ArrayListUnmanaged(query.Term),
    postings: std.ArrayList(PostingsHeader),
    topk: TopK,
    accumulators: []align(32) config.AccumulatorType,

    pub fn init(io: std.Io, allocator: std.mem.Allocator, dir: std.Io.Dir, index_filename: []const u8) !Self {
        const index_file = try dir.readFileAllocOptions(io, index_filename, allocator, std.Io.Limit.unlimited, .@"16", null);

        const max_segments = config.max_query_terms * ((1 << config.quantise_bits) - 1);
        const postings_buf = try allocator.alloc(u8, max_segments * @sizeOf(u32) * 2);

        const compression_buf = try allocator.alignedAlloc(u32, .@"16", 128);

        const index = try Index.init(index_file, postings_buf, compression_buf);

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

        const accumulators = try allocator.alignedAlloc(config.AccumulatorType, .@"32", index.docs.len);

        return .{
            .index = index,
            .snippets = index.hasSnippets(),
            .snippeter = snippeter,
            .query = try std.ArrayListUnmanaged(query.Term).initCapacity(allocator, config.max_query_terms),
            .postings = try std.ArrayList(PostingsHeader).initCapacity(allocator, config.max_query_terms),
            .topk = TopK.init(accumulators.ptr),
            .accumulators = accumulators,
        };
    }

    fn prunePostings(self: *Self) void {
        const budget: usize = @intFromFloat(@as(f64, @floatFromInt(self.index.docs.len)) * config.SearchProportion);
        var total: usize = 0;
        for (self.postings.items) |post|
            total += post.len;

        var impact: usize = 1;
        while (total > budget) {
            for (self.postings.items) |*post| {
                if (post.segments.len == 0)
                    continue;

                const last = post.segments[post.segments.len - 1];
                if (last.impact == impact) {
                    post.len -= last.len;
                    total -= last.len;
                    post.segments.len -= 1;
                }
            }
            impact += 1;
        }

        // Remove any postings that got emptied
        var i = self.postings.items.len;
        while (i > 0) : (i -= 1) {
            if (self.postings.items[i-1].len == 0)
                _ = self.postings.swapRemove(i-1);
        }
    }

    // Maps [@min(impact), @max(impact)] to [1, @intMax(AccumulatorType)]
    // Using the formula:
    //
    //            (x - @min) * (@intMax - 1)
    // f(x) = 1 + --------------------------
    //                 (@max - @min)
    //
    fn scalePostings(self: *Self) void {
        const accumulator_max: usize = std.math.maxInt(config.AccumulatorType) / self.postings.items.len - 1;

        var max_impact: usize = 0;
        var min_impact: usize = std.math.maxInt(config.AccumulatorType);
        for (self.postings.items) |post| {
            if (post.segments[0].impact > max_impact) max_impact = post.segments[0].impact;
            if (post.segments[post.segments.len - 1].impact < min_impact) min_impact = post.segments[post.segments.len - 1].impact;
        }

        if (max_impact < accumulator_max)
            return;

        const scale_factor: f64 = @as(f64, @floatFromInt(accumulator_max)) / @as(f64, @floatFromInt(max_impact - min_impact));

        for (self.postings.items) |post| {
            for (post.segments) |*segment| {
                const impact: f64 = segment.impact;
                segment.impact = @intFromFloat(1 + (impact - @as(f64, @floatFromInt(min_impact))) * scale_factor);
            }
        }
    }

    pub fn search(self: *Self, results: []Result, query_raw: []u8, prune: bool) ![]Result {
        self.index.reset();
        self.query.clearRetainingCapacity();

        var tok = query.Parser.init(Stemmer.init(self.index.header.stemmer), &self.query, query_raw);
        tok.parse();

        // TODO reenable once allocation is fixed
        // try expandQuery(allocator, &self.query);

        self.topk.clearRetainingCapacity();
        self.postings.clearRetainingCapacity();

        // TODO fix term negation
        for (self.query.items) |term| {
            const res = try self.index.find(term.term);
            if (res) |postings|
                self.postings.appendAssumeCapacity(postings);
        }

        // Special case for single term query skipping accumulator reset
        if (self.postings.items.len == 1)
            return self.index.readPostings(&self.postings.items[0], results);

        // It's unlikely we'll prune down to a single postings and pruning takes time
        if (prune)
            self.prunePostings();

        self.scalePostings();

        std.sort.pdq(PostingsHeader, self.postings.items, {}, cmpPostings);

        memset(std.mem.sliceAsBytes(self.accumulators));

        // Now process normally
        for (self.postings.items) |postings|
            self.index.accumulatePostings(&postings, &self.topk, self.accumulators);

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
