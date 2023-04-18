//	STR.ZIG
//	-------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

pub fn dup(allocator: std.mem.Allocator, slice: []const u8) ![]u8 {
    var newSlice = try allocator.alloc(u8, slice.len);
    std.mem.copy(u8, newSlice, slice);
    return newSlice;
}

pub fn stripPunct(out: []u8, in: []u8) []u8 {
    var i: usize = 0;
    for (in) |c| {
        if (std.ascii.isAlpha(c)) {
            out[i] = c;
            i += 1;
        }
    }
    return out[0..i];
}
