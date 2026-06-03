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
        \\
    );

    const cli_parsers = comptime .{
        .file = clap.parsers.string,
    };

    var res = try clap.parse(clap.Help, &params, cli_parsers, init.minimal.args, .{ .allocator = init.arena.allocator() });
    defer res.deinit();

    const index_file = try std.Io.Dir.cwd().readFileAlloc(init.io, config.index_name, init.arena.allocator(), std.Io.Limit.unlimited);
    const index = try Index.init(init.arena.allocator(), index_file);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    if (res.args.help != 0) {
        return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});
    } else if (res.args.docids != 0 or res.args.titles != 0) {
        for (0..index.docs_count) |id| {
            const doc_id = index.name(@truncate(id));
            if (res.args.docids != 0)
                try stdout.print("{s}\n", .{doc_id[0]});
            if (res.args.titles != 0)
                try stdout.print("{s}\n", .{doc_id[1]});
        }

        return;
    } else if (res.args.terms != 0) {
        const cap = read32(index_file, index.hash_offset);
        const table = index.hash_offset + @sizeOf(u32);

        for (0..cap) |i| {
            const postings_offset = table + i * @sizeOf(u64);

            const term_store = read32(index_file, postings_offset);
            if (term_store == 0)
                continue;
            const term_length = read16(index_file, term_store);
            const term_start = term_store + @sizeOf(u16);
            const term = index_file[term_start .. term_start + term_length];
            try stdout.print("{s}\n", .{term});
        }

        return;
    }

    try stdout.print("Index size: {Bi:.2}\n", .{index_file.len});
    try stdout.print("Docs: {d}\n", .{index.docs_count});
    try stdout.print("Longest doc: {d}\n", .{index.max_length});
    try stdout.print("Average doc length: {d:.2}\n", .{index.average_length});
}
