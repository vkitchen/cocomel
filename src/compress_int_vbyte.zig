//	COMPRESS_INT_VBYTE.ZIG
//	----------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

// Intended to be compatible with the scheme used in ATIRE
// i.e. big endian with a stop bit
// Reference: https://github.com/andrewtrotman/ATIRE/blob/master/source/compress_variable_byte.h

pub fn read(p: []const u8, out: *u32) u32 {
    out.* = p[0] & 0x7F;

    var i: u32 = 0;
    while (i < 4 and p[i] & 1 << 7 == 0) : (i += 1) {
        out.* <<= 7;
        out.* |= p[i + 1] & 0x7F;
    }

    return i + 1;
}

pub fn spaceRequired(val: u32) u32 {
    if (val < 1 << 7) {
        return 1;
    }
    if (val < 1 << 14) {
        return 2;
    }
    if (val < 1 << 21) {
        return 3;
    }
    if (val < 1 << 28) {
        return 4;
    } else {
        return 5;
    }
}

pub fn store(p: []u8, val: u32) u32 {
    if (val < 1 << 7) {
        p[0] = @truncate(u8, val & 0x7F | 1 << 7);
        return 1;
    }
    if (val < 1 << 14) {
        p[0] = @truncate(u8, val >> 7 & 0x7F);
        p[1] = @truncate(u8, val & 0x7F | 1 << 7);
        return 2;
    }
    if (val < 1 << 21) {
        p[0] = @truncate(u8, val >> 14 & 0x7F);
        p[1] = @truncate(u8, val >> 7 & 0x7F);
        p[2] = @truncate(u8, val & 0x7F | 1 << 7);
        return 3;
    }
    if (val < 1 << 28) {
        p[0] = @truncate(u8, val >> 21 & 0x7F);
        p[1] = @truncate(u8, val >> 14 & 0x7F);
        p[2] = @truncate(u8, val >> 7 & 0x7F);
        p[3] = @truncate(u8, val & 0x7F | 1 << 7);
        return 4;
    } else {
        p[0] = @truncate(u8, val >> 28 & 0x7F);
        p[1] = @truncate(u8, val >> 21 & 0x7F);
        p[2] = @truncate(u8, val >> 14 & 0x7F);
        p[3] = @truncate(u8, val >> 7 & 0x7F);
        p[4] = @truncate(u8, val & 0x7F | 1 << 7);
        return 5;
    }
}

test "vbyte" {
    const std = @import("std");

    var buffer: [5]u8 = undefined;
    var result: u32 = 0;
    var bytes_used: usize = 0;

    // One Byte
    bytes_used = store(&buffer, 8);
    try std.testing.expect(bytes_used == 1);
    bytes_used = read(&buffer, &result);
    try std.testing.expect(bytes_used == 1);
    try std.testing.expect(result == 8);

    // Two Byte
    bytes_used = store(&buffer, 1 << 8);
    try std.testing.expect(bytes_used == 2);
    bytes_used = read(&buffer, &result);
    try std.testing.expect(bytes_used == 2);
    try std.testing.expect(result == 1 << 8);

    // Three Byte
    bytes_used = store(&buffer, 1 << 15);
    try std.testing.expect(bytes_used == 3);
    bytes_used = read(&buffer, &result);
    try std.testing.expect(bytes_used == 3);
    try std.testing.expect(result == 1 << 15);

    // Four Byte
    bytes_used = store(&buffer, 1 << 22);
    try std.testing.expect(bytes_used == 4);
    bytes_used = read(&buffer, &result);
    try std.testing.expect(bytes_used == 4);
    try std.testing.expect(result == 1 << 22);

    // Five Byte
    bytes_used = store(&buffer, 1 << 29);
    try std.testing.expect(bytes_used == 5);
    bytes_used = read(&buffer, &result);
    try std.testing.expect(bytes_used == 5);
    try std.testing.expect(result == 1 << 29);
}
