// PROG_BENCHMARK_SEARCH.ZIG
// -------------------------
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

pub fn main(init: std.process.Init) !void {
    var arena = init.arena.allocator();

    stdin = std.Io.File.stdin().reader(init.io, &stdin_buffer);
    stdout = std.Io.File.stdout().writer(init.io, &stdout_buffer);

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\--index <file>         Search a different index than default.
        \\
    );

    const cli_parsers = comptime .{
        .file = clap.parsers.string,
    };

    const cli = try clap.parse(clap.Help, &params, cli_parsers, init.minimal.args, .{ .allocator = arena });

    if (cli.args.help != 0)
        return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});

    var index_name: []const u8 = config.index_name;
    if (cli.args.index) |index|
        index_name = index;

    const start_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    var searcher = try Search.init(init.io, arena, std.Io.Dir.cwd(), index_name);

    const read_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    var queries: std.ArrayList(struct { usize, []u8 }) = .empty;

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

        try queries.append(arena, .{ query_id, try arena.dupe(u8, query) });
    }

    var all_results = try arena.alloc([]Result, queries.items.len);
    for (0..queries.items.len) |i|
        all_results[i] = try arena.alloc(Result, 1000);

    const start_search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();
    for (queries.items, 0..) |query, i|
        all_results[i] = try searcher.search(all_results[i], query[1]);
    const end_search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    for (all_results, 0..) |results, qi| {
        for (0..@min(results.len, 1000)) |i| {
            const doc_id = searcher.name(results[i].docid);
            try stdout.interface.print("{d} Q0 {s} {d} {d} cocomel\n", .{ queries.items[qi][0], doc_id[0], i + 1, results[i].score });
        }
    }
    try stdout.flush();

    const total_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    std.debug.print("Index read time: {d:.3}s\n", .{@as(f64, @floatFromInt(read_time - start_time)) / 1e9});
    std.debug.print("Search time:     {d:.3}s\n", .{@as(f64, @floatFromInt(end_search_time - start_search_time)) / 1e9});
    std.debug.print("Total time:      {d:.3}s\n", .{@as(f64, @floatFromInt(total_time - start_time)) / 1e9});
}
