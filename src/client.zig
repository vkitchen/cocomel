//	CLIENT.ZIG
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
    const stdin = std.io.getStdIn().reader();

    std.debug.print("{s}", .{"Query> "});

    var buf: [1000]u8 = undefined;
    var query = try stdin.readUntilDelimiterOrEof(buf[4..], '\n');
    buf[0] = 0;
    buf[1] = 0;
    const len = @truncate(u16, query.?.len);
    const lenp = std.mem.asBytes(&len);
    std.mem.copy(u8, buf[2..], lenp);

    var results_buffer: [16384]u8 = undefined;

    var stream = try std.net.connectUnixSocket(socket_name);

    var bytes_written = try stream.write(buf[0 .. 4 + query.?.len]);
    std.debug.print("Wrote {d}\n", .{bytes_written});

    var total_read: usize = 0;
    while (true) {
        var bytes_read = try stream.read(results_buffer[total_read..]);
        if (bytes_read == 0)
            break;
        total_read += bytes_read;
    }

    const total_results = read16(&results_buffer, 0);
    const no_results = read16(&results_buffer, 2);

    std.debug.print("Top {d} results of ({d} total):\n\n", .{ no_results, total_results });

    var offset: usize = 4;

    var i: usize = 0;
    while (i < no_results) : (i += 1) {
        const name_len = read16(&results_buffer, offset);
        offset += 2;
        std.debug.print("{s}\n", .{results_buffer[offset .. offset + name_len]});
        offset += name_len;
        const snippet_len = read16(&results_buffer, offset);
        offset += 2;
        std.debug.print("{s}\n\n", .{results_buffer[offset .. offset + snippet_len]});
        offset += snippet_len;
    }
}
