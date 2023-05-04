//	PROG_SEARCH.ZIG
//	---------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Search = @import("search.zig").Search;

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var searcher = try Search.init(allocator, std.fs.cwd(), config.files.index, config.files.snippets);

    std.debug.print("{s}", .{"Query> "});

    var buf: [100]u8 = undefined;
    var query = try stdin.readUntilDelimiterOrEof(&buf, '\n');

    const results = try searcher.search(query.?);

    std.debug.print("Top 10 Results ({d} total):\n\n", .{results.len});

    var i: usize = 0;
    while (i < std.math.min(10, results.len)) : (i += 1) {
        std.debug.print("{d:.4} {s}\n", .{ results[i].score, searcher.name(results[i].doc_id) });
        const snippet = try searcher.snippet(results[i].doc_id);
        for (snippet, 0..) |s, j| {
            if (j > 0)
                std.debug.print(" ", .{});
            if (s.hit) {
                std.debug.print("\x1B[1m{s}\x1B[0m", .{s.original});
            } else {
                std.debug.print("{s}", .{s.original});
            }
        }
        std.debug.print("\n\n", .{});
    }
}
