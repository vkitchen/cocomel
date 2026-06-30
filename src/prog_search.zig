// PROG_SEARCH.ZIG
// ---------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const clap = @import("clap");

const config = @import("config.zig");
const Result = @import("index.zig").Result;
const Search = @import("search.zig").Search;

var stdin_buffer: [1024]u8 = undefined;
var stdout_buffer: [1024]u8 = undefined;

var stdin: std.Io.File.Reader = undefined;
var stdout: std.Io.File.Writer = undefined;

var results_buffer: [1000]Result = undefined;

var total_search_time: i96 = 0;

pub fn main(init: std.process.Init) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-k <int>               Print k results.
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

    stdin = std.Io.File.stdin().reader(init.io, &stdin_buffer);
    stdout = std.Io.File.stdout().writer(init.io, &stdout_buffer);

    std.debug.print("Reading index...\n", .{});

    const start_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    var searcher = try Search.init(init.io, init.arena.allocator(), std.Io.Dir.cwd(), index_name);

    const read_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    std.debug.print("Index read took: {d:.3}s\n", .{@as(f64, @floatFromInt(read_time - start_time)) / 1e9});
    std.debug.print("Query> ", .{});

    while (try stdin.interface.takeDelimiter('\n')) |query| {
        const start_search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

        const results = try searcher.search(&results_buffer, query);

        const end_search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();
        total_search_time += end_search_time - start_search_time;

        std.debug.print("Search took: {d:.3}s\n", .{@as(f64, @floatFromInt(end_search_time - start_search_time)) / 1e9});

        for (0..@min(results.len, num_results)) |i| {
            const doc_id = searcher.name(results[i].docid);

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

        try stdout.flush();

        std.debug.print("Query> ", .{});
    }

    std.debug.print("\nTotal search time: {d:.3}s\n", .{@as(f64, @floatFromInt(total_search_time)) / 1e9});
}
