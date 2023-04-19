//	FILE.ZIG
//	--------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

pub fn slurp(allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const stat = try file.stat();

    const buffer = try allocator.alloc(u8, stat.size);
    if (try file.readAll(buffer) != stat.size)
        return error.ReadError;

    return buffer;
}
