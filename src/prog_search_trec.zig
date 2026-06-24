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

    const start_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    var searcher = try Search.init(init.io, init.arena.allocator(), std.Io.Dir.cwd(), config.index_name);

    const read_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    var total_search_time: i96 = 0;

    while (try stdin.interface.takeDelimiter('\n')) |query_raw| {
        var query = query_raw;
        var query_id: usize = 0;
        if (std.mem.findScalar(u8, query, ' ')) |space| {
            if (std.fmt.parseInt(usize, query[0..space], 10)) |num| {
                query_id = num;
                query = query[space + 1 ..];
            } else |_| {
                query_id = 0;
            }
        }

        const start_search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

        const results = try searcher.search(query);

        const end_search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();
        total_search_time += end_search_time - start_search_time;

        for (0..@min(results.len, 1000)) |i| {
            const doc_id = searcher.name(results[i].docid);
            try stdout.interface.print("{d} Q0 {s} {d} {d} cocomel\n", .{ query_id, doc_id[0], i + 1, results[i].score });
        }
    }

    try stdout.flush();

    const total_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    std.debug.print("Index read time: {d:.3}s\n", .{@as(f64, @floatFromInt(read_time - start_time)) / 1e9});
    std.debug.print("Search time:     {d:.3}s\n", .{@as(f64, @floatFromInt(total_search_time)) / 1e9});
    std.debug.print("Total time:      {d:.3}s\n", .{@as(f64, @floatFromInt(total_time - start_time)) / 1e9});
}
