//	DAEMON.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Search = @import("search.zig").Search;

const socket_name = "/tmp/cocomel.sock";

fn read16(str: []const u8, offset: usize) u16 {
    return std.mem.bytesToValue(u16, str[offset .. offset + @sizeOf(u16)][0..2]);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var snippets_buf: [500]u8 = undefined;

    var searcher = try Search.init(allocator, &snippets_buf);
    defer searcher.deinit();

    var query_buf: [1024]u8 = undefined;

    try std.os.unlink(socket_name);

    var addr = try std.net.Address.initUnix(socket_name);
    var listener = std.net.StreamServer.init(.{});
    try listener.listen(addr);

    while (listener.accept()) |conn| {
        var bytes_read = try conn.stream.read(&query_buf);
        // TODO proper handling
        if (bytes_read < 4) {
            conn.stream.close();
            continue;
        }

        const protocol_version = query_buf[0];
        const protocol_method = query_buf[1];
        // TODO proper handling
        if (protocol_version != 0 or protocol_method != 0) {
            conn.stream.close();
            continue;
        }

        const str_len = read16(&query_buf, 2);
        // TODO proper handling
        if (bytes_read < 4 + str_len) {
            conn.stream.close();
            continue;
        }

        const results = try searcher.search(allocator, query_buf[4 .. 4 + str_len]);

        const no_results = std.math.min(10, results.len);

        var out = conn.stream.writer();

        try out.writeIntNative(u16, @truncate(u16, results.len));
        try out.writeIntNative(u16, @truncate(u16, no_results));

        var i: usize = 0;
        while (i < no_results) : (i += 1) {
            const name = searcher.name(results[i].doc_id);
            try out.writeIntNative(u16, @truncate(u16, name.len));
            try out.writeAll(name);
            var snippet_length: usize = 0;
            const snippet = try searcher.snippet(allocator, results[i].doc_id);
            for (snippet) |s, j| {
                if (j > 0)
                    snippet_length += 1;
                if (s.hit)
                    snippet_length += 7;
                snippet_length += s.original.len;
            }
            try out.writeIntNative(u16, @truncate(u16, snippet_length));
            for (snippet) |s, j| {
                if (j > 0)
                    try out.writeAll(" ");
                if (s.hit)
                    try out.writeAll("<b>");
                try out.writeAll(s.original);
                if (s.hit)
                    try out.writeAll("</b>");
            }
        }

        conn.stream.close();
    } else |err| {
        return err;
    }
}
