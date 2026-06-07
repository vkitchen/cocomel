// PROG_SEARCH_TREC.ZIG
// --------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Search = @import("search.zig").Search;

pub fn main(init: std.process.Init) !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(init.io, &stdin_buffer);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &stdout_buffer);

    var searcher = try Search.init(init.io, init.arena.allocator(), std.Io.Dir.cwd(), config.index_name);

    while (try stdin.interface.takeDelimiter('\n')) |query| {
        var query_id: usize = 0;
        if (std.mem.findScalar(u8, query, ' ')) |space|
            query_id = std.fmt.parseInt(usize, query[0..space], 10) catch 0;

        const results = try searcher.search(query);

        for (0..@min(results.len, 1000)) |i| {
            const doc_id = searcher.name(results[i].doc_id);
            try stdout.interface.print("{d} Q0 {s} {d} {d} cocomel\n", .{ query_id, doc_id[0], i + 1, results[i].score });
        }
    }

    try stdout.flush();
}
