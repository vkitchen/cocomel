// PROG_SEARCH.ZIG
// ---------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Search = @import("search.zig").Search;

pub fn main(init: std.process.Init) !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(init.io, &stdin_buffer);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var searcher = try Search.init(init.io, allocator, std.Io.Dir.cwd(), config.index_name);

    std.debug.print("{s}", .{"Query> "});

    const query = try stdin.interface.takeDelimiter('\n');

    const start_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    const results = try searcher.search(query.?);

    const search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    std.debug.print("Search took {d:.3}\n", .{@as(f64, @floatFromInt(search_time - start_time)) / 1e9});

    std.debug.print("Top 10 Results ({d} total):\n\n", .{results.len});

    var i: usize = 0;
    while (i < @min(10, results.len)) : (i += 1) {
        std.debug.print("{d:.4} {s}\n", .{ results[i].score, searcher.name(results[i].doc_id)[0] });
        std.debug.print("{s}\n", .{searcher.name(results[i].doc_id)[1]});
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
