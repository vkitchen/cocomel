//	SEARCH.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const Index = @import("index.zig").Index;
const Result = @import("index.zig").Result;
const Term = @import("tokenizer_snippet.zig").Term;
const Token = @import("tokenizer.zig").Token;
const QueryTokenizer = @import("tokenizer_query.zig").QueryTokenizer;
const Ranker = @import("ranking_fn.zig").Ranker;
const Snippeter = @import("snippets.zig").Snippeter;
const stem = @import("stem.zig").stem;
const expandQuery = @import("query_expansion.zig").expandQuery;
const config = @import("config.zig");

fn cmpResults(context: void, a: Result, b: Result) bool {
    return std.sort.desc(f64)(context, a.score, b.score);
}

pub const Search = struct {
    const Self = @This();

    index: Index,
    snippeter: Snippeter,
    ranker: Ranker,
    query: std.ArrayListUnmanaged([]u8),
    results: []Result,
    time_index_read: u64 = 0,
    time_snippets_read: u64 = 0,
    time_query: u64 = 0,
    time_search: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, dir: std.fs.Dir, index_filename: []const u8, snippets_filename: []const u8) !Self {
        var timer = try std.time.Timer.start();
        const index_file = try file.slurp(allocator, dir, index_filename);
        const time_index_read = timer.lap();
        const snippets_file = try file.slurp(allocator, dir, snippets_filename);
        const time_snippets_read = timer.read();

        const index = try Index.init(allocator, index_file);

        var max_snippet: u32 = 0;
        var doc_id: u32 = 0;
        while (doc_id < index.docs_count) : (doc_id += 1) {
            const range = index.snippet(doc_id);
            const snippet_length = range[1] - range[0];
            if (snippet_length > max_snippet)
                max_snippet = snippet_length;
        }

        // TODO make snippets optional

        var snippets_buf = try allocator.alloc(u8, max_snippet);
        var snippets_allocator = std.heap.FixedBufferAllocator.init(snippets_buf);
        var snippets_terms = try std.ArrayListUnmanaged(Term).initCapacity(allocator, index.max_length);
        var snippeter = try Snippeter.init(snippets_allocator, snippets_file, snippets_terms);

        return .{
            .index = index,
            .snippeter = snippeter,
            .ranker = Ranker.init(@intToFloat(f64, index.docs_count), index.average_length),
            .query = try std.ArrayListUnmanaged([]u8).initCapacity(allocator, config.max_query_terms),
            .results = try allocator.alloc(Result, index.docs_count),
            .time_index_read = time_index_read,
            .time_snippets_read = time_snippets_read,
        };
    }

    pub fn search(self: *Self, query: []u8) ![]Result {
        var timer = try std.time.Timer.start();

        var tok = QueryTokenizer.init(query);

        self.query.clearRetainingCapacity();

        while (true) {
            const t = tok.next();
            if (t.type == Token.Type.eof) break;
            var term = stem(t.token);
            self.query.appendAssumeCapacity(term);
        }

        // TODO reenable once allocation is fixed
        // try expandQuery(allocator, &self.query);

        self.time_query = timer.lap();

        var i: u32 = 0;
        while (i < self.results.len) : (i += 1) {
            self.results[i].doc_id = i;
            self.results[i].score = 0;
        }

        for (self.query.items) |term| {
            self.index.find(term, &self.ranker, self.results);
        }

        std.sort.sort(Result, self.results, {}, cmpResults);

        var results_count: usize = 0;
        for (self.results) |result| {
            if (result.score == 0)
                break;

            results_count += 1;
        }

        self.time_search = timer.lap();

        return self.results[0..results_count];
    }

    pub fn name(self: *const Self, doc_id: u32) []const u8 {
        return self.index.name(doc_id);
    }

    pub fn snippet(self: *Self, doc_id: u32) ![]Term {
        if (!config.snippets)
            return "";
        const range = self.index.snippet(doc_id);
        return self.snippeter.snippet(self.query.items, range[0], range[1]);
    }
};
