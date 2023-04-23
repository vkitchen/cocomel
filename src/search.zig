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
const snippets = @import("snippets.zig");
const stem = @import("stem.zig").stem;
const expandQuery = @import("query_expansion.zig").expandQuery;
const config = @import("config.zig");

fn cmpResults(context: void, a: Result, b: Result) bool {
    return std.sort.desc(f64)(context, a.score, b.score);
}

pub const Search = struct {
    const Self = @This();

    index: Index,
    ranker: Ranker,
    terms: std.ArrayList([]u8),
    results: []Result,
    snippets_file: std.fs.File = undefined,
    snippets_buf: []u8,
    snippets_terms: std.ArrayList(Term),
    time_index: u64 = 0,
    time_query: u64 = 0,
    time_search: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, snippets_buf: []u8) !Self {
        var timer = try std.time.Timer.start();

        const index_file = try file.slurp(allocator, config.files.index);
        const index = try Index.init(allocator, index_file);

        var time_index = timer.read();

        // TODO this should be dependent on whether the index references snippets. Not compile time flags
        var snippets_file: std.fs.File = undefined;
        if (config.snippets)
            snippets_file = try std.fs.cwd().openFile(config.files.snippets, .{});

        return .{
            .index = index,
            .ranker = Ranker.init(@intToFloat(f64, index.docs_count), index.average_length),
            .terms = std.ArrayList([]u8).init(allocator),
            .results = try allocator.alloc(Result, index.docs_count),
            .snippets_file = snippets_file,
            .snippets_buf = snippets_buf,
            .snippets_terms = std.ArrayList(Term).init(allocator),
            .time_index = time_index,
        };
    }

    pub fn deinit(self: *Self) void {
        if (config.snippets)
            self.snippets_file.close();
    }

    // TODO ideally this shouldn't allocate
    pub fn search(self: *Self, allocator: std.mem.Allocator, query: []u8) ![]Result {
        var timer = try std.time.Timer.start();

        var tok = QueryTokenizer.init(query);

        self.terms.clearRetainingCapacity();

        while (true) {
            const t = tok.next();
            if (t.type == Token.Type.eof) break;
            var term = stem(t.token);
            try self.terms.append(term);
        }

        // TODO this shouldn't allocate
        try expandQuery(allocator, &self.terms);

        self.time_query = timer.lap();

        var i: u32 = 0;
        while (i < self.results.len) : (i += 1) {
            self.results[i].doc_id = i;
            self.results[i].score = 0;
        }

        for (self.terms.items) |term| {
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

    pub fn snippet(self: *Self, allocator: std.mem.Allocator, doc_id: u32) ![]Term {
        if (!config.snippets)
            return "";
        self.snippets_terms.clearRetainingCapacity();
        var range = self.index.snippet(doc_id);
        return snippets.snippet(allocator, self.terms, &self.snippets_terms, self.snippets_file, range[0], range[1]);
    }
};
