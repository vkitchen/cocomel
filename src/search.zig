// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const Index = @import("index.zig").Index;
const PostingsHeader = @import("index.zig").PostingsHeader;
const Result = @import("result.zig");
const Term = @import("tokenizer_snippet.zig").Term;
const Token = @import("tokenizer.zig").Token;
const TopK = @import("top_k.zig").TopK;
const QueryTerm = @import("tokenizer_query.zig").Term;
const QueryParser = @import("tokenizer_query.zig").Parser;
const Stemmer = @import("stem.zig").Stemmer;
const Snippeter = @import("snippets.zig");
const stem = @import("stem.zig").stem;
const expandQuery = @import("query_expansion.zig").expandQuery;
const config = @import("config.zig");

const c = @import("c");

fn memset(dest: []align(32) u8) void {
    c.memset_avx2(dest.ptr, dest.len);
}

const Self = @This();

index: Index,
snippets: bool,
snippeter: Snippeter,
query: std.ArrayListUnmanaged(QueryTerm),
postings: std.ArrayList(PostingsHeader),
topk: TopK,
accumulators: []align(32) config.AccumulatorType,
postings_allocator: std.heap.FixedBufferAllocator,

pub fn init(io: std.Io, allocator: std.mem.Allocator, index_filename: []const u8) !Self {
    const index_file = try std.Io.Dir.cwd().readFileAllocOptions(io, index_filename, allocator, std.Io.Limit.unlimited, .@"16", null);

    const max_segments = config.max_query_terms * ((1 << config.quantise_bits) - 1);
    const postings_buf = try allocator.alloc(u8, max_segments * @sizeOf(u32) * 2);

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

    const accumulators = try allocator.alignedAlloc(config.AccumulatorType, .@"32", index.docs.len);

    return .{
        .index = index,
        .snippets = index.hasSnippets(),
        .snippeter = snippeter,
        .query = try std.ArrayListUnmanaged(QueryTerm).initCapacity(allocator, config.max_query_terms),
        .postings = try std.ArrayList(PostingsHeader).initCapacity(allocator, config.max_query_terms),
        .topk = TopK.init(accumulators.ptr),
        .accumulators = accumulators,
        .postings_allocator = std.heap.FixedBufferAllocator.init(postings_buf),
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
        if (self.postings.items[i - 1].len == 0)
            _ = self.postings.swapRemove(i - 1);
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
    for (self.postings.items, 0..) |post, i| {
        const term_count = self.query.items[i].count;
        const first_impact = term_count * post.segments[0].impact;
        const last_impact = term_count * post.segments[post.segments.len - 1].impact;

        if (first_impact > max_impact) max_impact = first_impact;
        if (last_impact < min_impact) min_impact = last_impact;
    }

    if (max_impact < accumulator_max)
        return;

    const scale_factor: f64 = @as(f64, @floatFromInt(accumulator_max)) / @as(f64, @floatFromInt(max_impact - min_impact));

    for (self.postings.items, 0..) |post, i| {
        const term_count = self.query.items[i].count;

        for (post.segments) |*segment| {
            var impact: f64 = segment.impact;
            impact *= @floatFromInt(term_count);
            segment.impact = @intFromFloat(1 + (impact - @as(f64, @floatFromInt(min_impact))) * scale_factor);
        }
    }
}

fn cmpQuery(_: void, a: QueryTerm, b: QueryTerm) bool {
    return std.mem.order(u8, a.term, b.term) == .lt;
}

pub fn search(self: *Self, results: []Result, query_raw: []u8, start: usize, end: usize, prune: bool) ![]Result {
    self.postings_allocator.reset();
    self.query.clearRetainingCapacity();

    var tok = QueryParser.init(Stemmer.init(self.index.header.stemmer), &self.query, query_raw);
    tok.parse();

    // TODO move this somewhere else and collect frequencies
    // sort
    std.sort.pdq(QueryTerm, self.query.items, {}, cmpQuery);
    var to: usize = 1;
    var from: usize = 1;
    // dedupe
    while (from < self.query.items.len) : (from += 1) {
        if (std.mem.eql(u8, self.query.items[from-1].term, self.query.items[from].term)) {
            self.query.items[to-1].count += 1;
        } else {
            self.query.items[to] = self.query.items[from];
            to += 1;
        }
    }
    self.query.items.len = to;

    self.postings.clearRetainingCapacity();

    for (0..self.query.items.len) |i| {
        const res = try self.index.find(self.postings_allocator.allocator(), self.query.items[i].term);
        if (res) |postings| {
            self.postings.appendAssumeCapacity(postings);
        } else {
            self.query.items[i].count = 0;
        }
    }

    // Remove failed queries
    to = 0;
    for (0..self.query.items.len) |i| {
        if (self.query.items[i].count != 0) {
            self.query.items[to] = self.query.items[i];
            to += 1;
        }
    }
    self.query.items.len = to;

    // No results found
    if (self.postings.items.len == 0)
        return &.{};

    // Special case for single term query skipping accumulator reset
    if (self.postings.items.len == 1)
        return self.index.readPostings(&self.postings.items[0], results[start..end]);

    // It's unlikely we'll prune down to a single postings and pruning takes time
    if (prune)
        self.prunePostings();

    self.scalePostings();

    memset(std.mem.sliceAsBytes(self.accumulators));

    self.topk.clearRetainingCapacity();
    self.topk.resize(end);

    // Now process normally
    for (self.postings.items) |postings|
        self.index.accumulatePostings(&postings, &self.topk, self.accumulators);

    return self.topk.results(results)[start..end];
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
