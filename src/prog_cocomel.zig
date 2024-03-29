//	PROG_COCOMEL.ZIG
//	----------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Search = @import("search.zig").Search;
const native_endian = @import("builtin").target.cpu.arch.endian();

const socket_name = "/tmp/cocomel.sock";

fn read16(str: []const u8, offset: usize) u16 {
    return std.mem.bytesToValue(u16, str[offset .. offset + @sizeOf(u16)][0..2]);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const dir = if (args.len == 1) std.fs.cwd() else try std.fs.openDirAbsolute(args[1], .{});

    var searcher = try Search.init(allocator, dir, config.files.index, config.files.snippets);

    var query_buf: [1024]u8 = undefined;

    std.os.unlink(socket_name) catch {};

    const addr = try std.net.Address.initUnix(socket_name);
    var listener = std.net.StreamServer.init(.{});
    try listener.listen(addr);

    while (listener.accept()) |conn| {
        const bytes_read = try conn.stream.read(&query_buf);
        // TODO proper handling
        if (bytes_read < 4) {
            conn.stream.close();
            continue;
        }

        const protocol_version = query_buf[0];
        const protocol_method = query_buf[1];
        // TODO proper handling
        if (protocol_version != 0 or protocol_method != 1) {
            conn.stream.close();
            continue;
        }

        const no_results = read16(&query_buf, 2);
        const results_offset = read16(&query_buf, 4);

        const str_len = read16(&query_buf, 6);
        // TODO proper handling
        if (bytes_read < 8 + str_len) {
            conn.stream.close();
            continue;
        }

        const results = try searcher.search(query_buf[8 .. 8 + str_len]);

        var out_buf = std.io.bufferedWriter(conn.stream.writer());
        var out = out_buf.writer();

        try out.writeInt(u8, 0, native_endian); // protocol version
        try out.writeInt(u8, 1, native_endian); // protocol method
        try out.writeInt(u16, @truncate(results.len), native_endian);
        if (results_offset > results.len) {
            try out.writeInt(u16, 0, native_endian);
        } else if (results.len - results_offset < no_results) {
            try out.writeInt(u16, @truncate(results.len - results_offset), native_endian);
        } else {
            try out.writeInt(u16, @truncate(no_results), native_endian);
        }

        var i: usize = results_offset;
        while (i < results_offset + no_results and i < results.len) : (i += 1) {
            // url
            const names = searcher.name(results[i].doc_id);
            try out.writeInt(u16, @truncate(names[0].len), native_endian);
            try out.writeAll(names[0]);
            // doc name
            try out.writeInt(u16, @truncate(names[1].len), native_endian);
            if (names[1].len > 0)
                try out.writeAll(names[1]);
            // snippet
            var snippet_length: usize = 0;
            const snippet = try searcher.snippet(results[i].doc_id);
            for (snippet, 0..) |s, j| {
                if (j > 0)
                    snippet_length += 1;
                if (s.hit)
                    snippet_length += 7;
                snippet_length += s.original.len;
            }
            try out.writeInt(u16, @truncate(snippet_length), native_endian);
            for (snippet, 0..) |s, j| {
                if (j > 0)
                    try out.writeAll(" ");
                if (s.hit)
                    try out.writeAll("<b>");
                try out.writeAll(s.original);
                if (s.hit)
                    try out.writeAll("</b>");
            }
        }

        try out_buf.flush();

        conn.stream.close();
    } else |err| {
        return err;
    }
}
