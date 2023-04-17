//	SEARCH.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const Index = @import("index.zig").Index;
const Result = @import("index.zig").Result;
const Token = @import("tokenizer.zig").Token;
const QueryTokenizer = @import("tokenizer_query.zig").QueryTokenizer;
const Ranker = @import("ranking_fn_bm25.zig").Ranker;
const stem = @import("stem_s.zig").stem;
const expandQuery = @import("query_expansion.zig").expandQuery;

fn cmpResults(context: void, a: Result, b: Result) bool {
    return std.sort.desc(f64)(context, a.score, b.score);
}

pub const Search = struct {
    const Self = @This();

    index: Index,
    ranker: Ranker,
    terms: std.ArrayList([]u8),
    results: []Result,
    results_count: u64 = 0,
    time_index: u64 = 0,
    time_query: u64 = 0,
    time_search: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var timer = try std.time.Timer.start();

        const index_file = try file.slurp(allocator, "index.dat");
        const index = Index.init(index_file);

        var time_index = timer.read();

        return .{
            .index = index,
            .ranker = Ranker.init(@intToFloat(f64, index.docs_count), index.average_length),
            .terms = std.ArrayList([]u8).init(allocator),
            .results = try allocator.alloc(Result, index.docs_count),
            .time_index = time_index,
        };
    }

    // TODO ideally this shouldn't allocate
    pub fn search(s: *Self, allocator: std.mem.Allocator, query: []u8) !void {
        var timer = try std.time.Timer.start();

        var tok = QueryTokenizer.init(query);

        s.terms.clearRetainingCapacity();

        while (true) {
            const t = tok.next();
            if (t.type == Token.Type.eof) break;
            var term = stem(t.token);
            try s.terms.append(term);
        }

        // TODO this shouldn't allocate
        try expandQuery(allocator, &s.terms);

        s.time_query = timer.lap();

        var i: u32 = 0;
        while (i < s.results.len) : (i += 1) {
            s.results[i].doc_id = i;
            s.results[i].score = 0;
        }

        for (s.terms.items) |term| {
            s.index.find(term, &s.ranker, s.results);
        }

        std.sort.sort(Result, s.results, {}, cmpResults);

        s.results_count = 0;
        for (s.results) |result| {
            if (result.score == 0)
                break;

            s.results_count += 1;
        }

        s.time_search = timer.lap();
    }
};
