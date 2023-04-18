//	COMPRESS_INT_VBYTE.ZIG
//	----------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

// Intended to be compatible with the scheme used in ATIRE
// i.e. big endian with a stop bit
// Reference: https://github.com/andrewtrotman/ATIRE/blob/master/source/compress_variable_byte.h

pub fn read(p: []u8, out: *u32) usize {
    out.* = p[0] & 0x7F;
    if (p[0] & 1 << 7 != 0)
        return 1;
    out.* <<= 7;
    out.* |= p[1] & 0x7F;
    if (p[1] & 1 << 7 != 0)
        return 2;
    out.* <<= 7;
    out.* |= p[2] & 0x7F;
    if (p[2] & 1 << 7 != 0)
        return 3;
    out.* <<= 7;
    out.* |= p[3] & 0x7F;
    if (p[3] & 1 << 7 != 0)
        return 4;
    out.* <<= 7;
    out.* |= p[4] & 0x7F;
    return 5;
}

pub fn store(p: []u8, val: u32) usize {
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

    // One Byte
    _ = store(&buffer, 8);
    _ = read(&buffer, &result);
    try std.testing.expect(result == 8);

    // Two Byte
    _ = store(&buffer, 1 << 8);
    _ = read(&buffer, &result);
    std.debug.print("SENT {d} GOT BACK {d}\n", .{ 1 << 8, result });
    try std.testing.expect(result == 1 << 8);

    // Three Byte
    _ = store(&buffer, 1 << 15);
    _ = read(&buffer, &result);
    std.debug.print("SENT {d} GOT BACK {d}\n", .{ 1 << 15, result });
    try std.testing.expect(result == 1 << 15);

    // Four Byte
    _ = store(&buffer, 1 << 22);
    _ = read(&buffer, &result);
    std.debug.print("SENT {d} GOT BACK {d}\n", .{ 1 << 22, result });
    try std.testing.expect(result == 1 << 22);

    // Five Byte
    _ = store(&buffer, 1 << 29);
    _ = read(&buffer, &result);
    std.debug.print("SENT {d} GOT BACK {d}\n", .{ 1 << 29, result });
    try std.testing.expect(result == 1 << 29);
}
