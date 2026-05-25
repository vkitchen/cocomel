// PROG_CLIENT.ZIG
// ---------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Search = @import("search.zig").Search;

const socket_name = "/tmp/cocomel.sock";

fn read16(str: []const u8, offset: usize) u16 {
    return std.mem.bytesToValue(u16, str[offset .. offset + @sizeOf(u16)][0..2]);
}

pub fn main(init: std.process.Init) !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(init.io, &stdin_buffer);

    std.debug.print("{s}", .{"Query> "});

    var buf: [1000]u8 = undefined;
    const query = try stdin.interface.takeDelimiter('\n');
    buf[0] = 0; // Version
    buf[1] = 1; // Command (Query)
    // No. results
    buf[2] = 5; // Little endian
    buf[3] = 0;
    // Offset
    buf[4] = 0;
    buf[5] = 0;
    const len: u16 = @truncate(query.?.len);
    const lenp = std.mem.asBytes(&len);
    @memcpy(buf[6..8], lenp);
    @memcpy(buf[8 .. 8 + len], query.?);

    var results_buffer: [16384]u8 = undefined;

    const start_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    const addr = try std.Io.net.UnixAddress.init(socket_name);
    var stream = try addr.connect(init.io);

    var reader_buf: [1024]u8 = undefined;
    var reader = stream.reader(init.io, &reader_buf);

    var writer_buf: [1024]u8 = undefined;
    var writer = stream.writer(init.io, &writer_buf);

    _ = try writer.interface.write(buf[0 .. 8 + query.?.len]);
    try writer.interface.flush();

    var total_read: usize = 0;
    while (true) {
        const bytes_read = try reader.interface.readSliceShort(results_buffer[total_read..]);
        if (bytes_read == 0)
            break;
        total_read += bytes_read;
    }

    stream.close(init.io);

    const search_time = std.Io.Clock.now(.real, init.io).toNanoseconds();

    std.debug.print("Search took {d:.3}\n", .{@as(f64, @floatFromInt(search_time - start_time)) / 1e9});

    // Skip version and method
    const total_results = read16(&results_buffer, 2);
    const no_results = read16(&results_buffer, 4);

    std.debug.print("Top {d} results of ({d} total):\n\n", .{ no_results, total_results });

    var offset: usize = 6;

    var i: usize = 0;
    while (i < no_results) : (i += 1) {
        const name_len = read16(&results_buffer, offset);
        offset += 2;
        std.debug.print("{s}\n", .{results_buffer[offset .. offset + name_len]});
        offset += name_len;
        const title_len = read16(&results_buffer, offset);
        offset += 2;
        if (title_len > 0) {
            std.debug.print("{s}\n", .{results_buffer[offset .. offset + title_len]});
            offset += title_len;
        }
        const snippet_len = read16(&results_buffer, offset);
        offset += 2;
        std.debug.print("{s}\n\n", .{results_buffer[offset .. offset + snippet_len]});
        offset += snippet_len;
    }
}
