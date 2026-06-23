// PROG_SEARCH.ZIG
// ---------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const clap = @import("clap");

const config = @import("config.zig");
const Search = @import("search.zig").Search;

var stdin_buffer: [1024]u8 = undefined;
var stdout_buffer: [1024]u8 = undefined;

pub fn main(init: std.process.Init) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-k <int>               Print k results.
        \\--trec                 Print results in trec format.
        \\--index <file>         Search a different index than default.
        \\
    );

    const cli_parsers = comptime .{
        .int = clap.parsers.int(usize, 0),
        .file = clap.parsers.string,
    };

    const cli = try clap.parse(clap.Help, &params, cli_parsers, init.minimal.args, .{ .allocator = init.arena.allocator() });

    if (cli.args.help != 0)
        return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});

    var num_results: usize = 10;
    if (cli.args.k) |k|
        num_results = k;

    var index_name: []const u8 = config.index_name;
    if (cli.args.index) |index|
        index_name = index;

    var stdin = std.Io.File.stdin().reader(init.io, &stdin_buffer);
    var stdout = std.Io.File.stdout().writer(init.io, &stdout_buffer);

    const start_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    var searcher = try Search.init(init.io, init.arena.allocator(), std.Io.Dir.cwd(), index_name);

    const read_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    var total_search_time: i96 = 0;

    std.debug.print("Ready...\n", .{});

    while (try stdin.interface.takeDelimiter('\n')) |query_raw| {
        var query = query_raw;
        var query_id: usize = 0;
        if (cli.args.trec != 0) {
            if (std.mem.findScalar(u8, query, ' ')) |space| {
                if (std.fmt.parseInt(usize, query[0..space], 10)) |num| {
                    query_id = num;
                    query = query[space+1..];
                } else |_| {
                    query_id = 0;
                }
            }
        }

        const start_search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

        const results = try searcher.search(query);

        const end_search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();
        total_search_time += end_search_time - start_search_time;

        for (0..@min(results.len, num_results)) |i| {
            const doc_id = searcher.name(results[i].docid);

            if (cli.args.trec != 0) {
                try stdout.interface.print("{d} Q0 {s} {d} {d} cocomel\n", .{ query_id, doc_id[0], i + 1, results[i].score });
            } else {
                try stdout.interface.print("{d} {s}\n", .{ results[i].score, doc_id[0] });
                if (doc_id[1].len != 0)
                    try stdout.interface.print("{s}\n", .{doc_id[1]});
                const snippet = try searcher.snippet(results[i].docid);
                if (snippet.len != 0) {
                    for (snippet, 0..) |s, j| {
                        if (j > 0)
                            try stdout.interface.print(" ", .{});
                        if (s.hit) {
                            try stdout.interface.print("\x1B[1m{s}\x1B[0m", .{s.original});
                        } else {
                            try stdout.interface.print("{s}", .{s.original});
                        }
                    }
                    try stdout.interface.print("\n\n", .{});
                }
            }
        }

        try stdout.flush();
    }

    const total_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    std.debug.print("Index read time: {d:.3}s\n", .{@as(f64, @floatFromInt(read_time - start_time)) / 1e9});
    std.debug.print("Search time:     {d:.3}s\n", .{@as(f64, @floatFromInt(total_search_time)) / 1e9});
    std.debug.print("Total time:      {d:.3}s\n", .{@as(f64, @floatFromInt(total_time - start_time)) / 1e9});
}
