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
const stem = @import("stem_s.zig").stem;
const expandQuery = @import("query_expansion.zig").expandQuery;
const Search = @import("search.zig").Search;

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var snippets_buf: [500]u8 = undefined;

    var searcher = try Search.init(allocator, &snippets_buf);
    defer searcher.deinit();

    std.debug.print("{s}", .{"Query> "});

    var buf: [100]u8 = undefined;
    var query = try stdin.readUntilDelimiterOrEof(&buf, '\n');

    const results = try searcher.search(allocator, query.?);

    std.debug.print("Top 10 Results ({d} total):\n\n", .{results.len});

    var i: usize = 0;
    while (i < std.math.min(10, results.len)) : (i += 1) {
        std.debug.print("{d:.4} {s}\n", .{ results[i].score, searcher.name(results[i].doc_id) });
        std.debug.print("{s}\n\n", .{try searcher.snippet(results[i].doc_id)});
    }
}
