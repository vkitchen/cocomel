//	SEARCH.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const Index = @import("index.zig").Index;
const Result = @import("index.zig").Result;
const tokenizer = @import("tokenizer.zig");
const QueryTokenizer = tokenizer.QueryTokenizer;
const Token = tokenizer.Token;
const Ranker = @import("ranking_fn.zig").Ranker;

fn cmpResults(context: void, a: Result, b: Result) bool {
    return std.sort.desc(f64)(context, a.score, b.score);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    std.debug.print("{s}\n", .{"Reading index..."});
    const index_file = try file.slurp(allocator, "index.dat");
    std.debug.print("Index size {d}\n", .{index_file.len});

    const index = Index.init(index_file);
    std.debug.print("No. docs {d}\n", .{index.docs_count});

    var snippets_file = try std.fs.cwd().openFile("snippets.dat", .{});
    defer snippets_file.close();
    var snippets_buf: [500]u8 = undefined;

    var ranker = Ranker.init(@intToFloat(f64, index.docs_count), index.average_length);

    var results = try allocator.alloc(Result, index.docs_count);
    var i: u32 = 0;
    while (i < index.docs_count) : (i += 1) {
        results[i].doc_id = i;
        results[i].score = 0;
    }

    std.debug.print("{s}", .{"Query> "});
    const stdin = std.io.getStdIn().reader();

    var buf: [100]u8 = undefined;
    var input = try stdin.readUntilDelimiterOrEof(&buf, '\n');

    var tok = QueryTokenizer.init(input.?);

    while (true) {
        const t = tok.next();
        if (t.type == Token.Type.eof) break;
        index.find(t.token, &ranker, results);
    }

    std.debug.print("Searching: {s}\n", .{input.?});
    std.sort.sort(Result, results, {}, cmpResults);

    var results_count: u32 = 0;
    for (results) |result| {
        if (result.score == 0)
            break;

        results_count += 1;
    }

    std.debug.print("Top 10 Results ({d} total):\n\n", .{results_count});

    i = 0;
    while (i < std.math.min(10, results_count)) : (i += 1) {
        std.debug.print("{d:.4} {s}\n", .{ results[i].score, index.name(results[i].doc_id) });
        std.debug.print("{s}\n\n", .{try index.snippet(results[i].doc_id, &snippets_buf, snippets_file)});
    }
}
