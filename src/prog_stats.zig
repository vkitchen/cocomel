// PROG_STATS.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const clap = @import("clap");

const config = @import("config.zig");
const Index = @import("index.zig").Index;

fn read16(str: []const u8, offset: usize) u16 {
    return std.mem.bytesToValue(u16, str[offset .. offset + @sizeOf(u16)][0..2]);
}

fn read32(str: []const u8, offset: usize) u32 {
    return std.mem.bytesToValue(u32, str[offset .. offset + @sizeOf(u32)][0..4]);
}

pub fn main(init: std.process.Init) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\--docids               Print docids.
        \\--titles               Print titles.
        \\--terms                Print terms.
        \\--index <file>         Use a different index than default.
        \\
    );

    const cli_parsers = comptime .{
        .file = clap.parsers.string,
    };

    var cli = try clap.parse(clap.Help, &params, cli_parsers, init.minimal.args, .{ .allocator = init.arena.allocator() });
    defer cli.deinit();

    var index_name: []const u8 = config.index_name;
    if (cli.args.index) |index|
        index_name = index;

    const index_file = try std.Io.Dir.cwd().readFileAllocOptions(init.io, index_name, init.arena.allocator(), std.Io.Limit.unlimited, .@"16", null);
    const index = try Index.init(index_file);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    if (cli.args.help != 0) {
        return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});
    } else if (cli.args.docids != 0 or cli.args.titles != 0) {
        for (0..index.docs.len) |id| {
            const doc_id = index.name(@truncate(id));
            if (cli.args.docids != 0)
                try stdout.print("{s}\n", .{doc_id[0]});
            if (cli.args.titles != 0)
                try stdout.print("{s}\n", .{doc_id[1]});
        }

        return;
    } else if (cli.args.terms != 0) {
        for (index.vocab) |store| {
            if (store.term == 0)
                continue;
            const term_length = read16(index.postings_store, store.term);
            const term_start = store.term + @sizeOf(u16);
            const term = index.postings_store[term_start .. term_start + term_length];
            try stdout.print("{s}\n", .{term});
        }

        return;
    }

    const structures_size = (index.snippets.len + index.vocab.len * 2 + index.docs.len + 3) * @sizeOf(config.FileOffsetType);

    // Count terms
    var term_count: usize = 0;
    for (index.vocab) |store| {
        if (store.term == 0)
            continue;
        term_count += 1;
    }

    try stdout.print("Index size:      {Bi:.2}\n", .{index_file.len});
    try stdout.print("Snippets size:   {Bi:.2}\n", .{index.snippets_store.len});
    try stdout.print("Blocks size:     {Bi:.2}\n", .{index.blocks_store.len});
    try stdout.print("Postings size:   {Bi:.2}\n", .{index.postings_store.len});
    try stdout.print("Docs size:       {Bi:.2}\n", .{index.docs_store.len});
    try stdout.print("Structures size: {Bi:.2}\n", .{structures_size});
    try stdout.print("\n", .{});

    try stdout.print("No. terms:       {d}\n", .{term_count});
    try stdout.print("No. docs:        {d}\n", .{index.docs.len});
    try stdout.print("Longest doc:     {d}\n", .{index.header.max_doc_length});
}
