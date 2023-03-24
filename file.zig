//	FILE.ZIG
//	--------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

pub fn slurp(allocator: std.mem.Allocator, filename: []u8) ![]u8
	{
	var file = try std.fs.cwd().openFile(filename, .{});
	defer file.close();

	const stat = try file.stat();
	std.debug.print("FILE SIZE: {d}\n", .{stat.size});

	const buffer = try allocator.alloc(u8, stat.size);
	_ = try file.readAll(buffer); // TODO did we read entire file?

	return buffer;
	}
