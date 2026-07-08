// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const clap = @import("clap");
const config = @import("config.zig");
const Result = @import("result.zig");
const Search = @import("search.zig");
const TopK = @import("top_k.zig");
const native_endian = @import("builtin").target.cpu.arch.endian();

var results_buffer: [1000]Result = undefined;

const Header = extern struct {
    version: u8,
    method: u8,
};

const SearchReq = extern struct {
    no_results: u16,
    offset: u16,
    query_len: u16,
};

fn read16(str: []const u8, offset: usize) u16 {
    return std.mem.bytesToValue(u16, str[offset .. offset + @sizeOf(u16)][0..2]);
}

pub fn main(init: std.process.Init) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\--index <file>         Search a different index than default.
        \\--exhaustive           Search to completion (don't terminate early).
        \\
    );

    const cli_parsers = comptime .{
        .file = clap.parsers.string,
        .name = clap.parsers.string,
    };

    const cli = try clap.parse(clap.Help, &params, cli_parsers, init.minimal.args, .{ .allocator = init.arena.allocator() });

    if (cli.args.help != 0)
        return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});

    var index_name: []const u8 = config.index_name;
    if (cli.args.index) |index|
        index_name = index;

    const prune = cli.args.exhaustive == 0;

    var searcher = try Search.init(init.io, init.gpa, index_name);

    std.Io.Dir.deleteFileAbsolute(init.io, config.socket_name) catch {};

    const addr = try std.Io.net.UnixAddress.init(config.socket_name);
    var listener = try addr.listen(init.io, .{});

    while (listener.accept(init.io)) |conn| {
        var reader_buf: [1024]u8 = undefined;
        var reader = conn.reader(init.io, &reader_buf);

        var writer_buf: [1024]u8 = undefined;
        var writer = conn.writer(init.io, &writer_buf);

        const header = try reader.interface.takeStruct(Header, native_endian);
        // TODO proper handling
        if (header.version != 1) {
            conn.close(init.io);
            continue;
        }

        // Info
        if (header.method == 2) {
            try writer.interface.writeInt(u8, 1, native_endian); // protocol version
            try writer.interface.writeInt(u8, 2, native_endian); // protocol method
            try writer.interface.writeInt(u32, @truncate(searcher.index.docs.len), native_endian);
            try writer.interface.flush();

            conn.close(init.io);
            continue;
        }

        const query_header = try reader.interface.takeStruct(SearchReq, native_endian);
        const query = try reader.interface.take(query_header.query_len);

        // TODO proper handling
        if (header.method != 3) {
            conn.close(init.io);
            continue;
        }

        const results = try searcher.search(&results_buffer, query, query_header.offset, query_header.offset + query_header.no_results, prune);

        try writer.interface.writeInt(u8, 1, native_endian); // protocol version
        try writer.interface.writeInt(u8, 3, native_endian); // protocol method
        try writer.interface.writeInt(u16, @truncate(results.len), native_endian);
        if (query_header.offset > results.len) {
            try writer.interface.writeInt(u16, 0, native_endian);
        } else if (results.len - query_header.offset < query_header.no_results) {
            try writer.interface.writeInt(u16, @truncate(results.len - query_header.offset), native_endian);
        } else {
            try writer.interface.writeInt(u16, @truncate(query_header.no_results), native_endian);
        }

        var i: usize = query_header.offset;
        while (i < query_header.offset + query_header.no_results and i < results.len) : (i += 1) {
            // url
            const names = searcher.name(results[i].docid);
            try writer.interface.writeInt(u16, @truncate(names[0].len), native_endian);
            try writer.interface.writeAll(names[0]);
            // doc name
            try writer.interface.writeInt(u16, @truncate(names[1].len), native_endian);
            if (names[1].len > 0)
                try writer.interface.writeAll(names[1]);
            // snippet
            var snippet_length: usize = 0;
            const snippet = try searcher.snippet(results[i].docid);
            for (snippet, 0..) |s, j| {
                if (j > 0)
                    snippet_length += 1;
                if (s.hit)
                    snippet_length += 7;
                snippet_length += s.original.len;
            }
            try writer.interface.writeInt(u16, @truncate(snippet_length), native_endian);
            for (snippet, 0..) |s, j| {
                if (j > 0)
                    try writer.interface.writeAll(" ");
                if (s.hit)
                    try writer.interface.writeAll("<b>");
                try writer.interface.writeAll(s.original);
                if (s.hit)
                    try writer.interface.writeAll("</b>");
            }
        }

        try writer.interface.flush();

        conn.close(init.io);
    } else |err| {
        return err;
    }
}
