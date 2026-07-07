// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");

const config = @import("config.zig");

const c = @import("c");

const default_compressor = fromName(config.default_compressor);
pub const default = if (default_compressor == .failed) @compileError(std.fmt.comptimePrint("Unknown compressor {s}", .{config.default_compressor})) else default_compressor;

pub const Compressor = enum(u8) {
    none,
    vbyte,
    bp128,
    failed,
};

const CompressorNames = [_][]const u8{
    "none",
    "vbyte",
    "bp128",
};

pub fn fromName(compressor: []const u8) Compressor {
    for (CompressorNames, 0..) |name, i| {
        if (std.mem.eql(u8, compressor, name))
            return @enumFromInt(i);
    }

    return .failed;
}

pub inline fn pack_stream(compressor: Compressor, blocks: []u128, bytes: []u8, docs: []const u32) c.struct_compress_res {
    return switch (compressor) {
        .vbyte => c.compress_int_vbyte_pack_stream(@ptrCast(blocks.ptr), bytes.ptr, docs.ptr, docs.len),
        .bp128 => c.compress_int_bp128_pack_stream(@ptrCast(blocks.ptr), bytes.ptr, docs.ptr, docs.len),
        else => unreachable,
    };
}

pub inline fn unpack_block_d1(compressor: Compressor, blocks: []const u128, bytes: []const u8, docs: []u32, len: usize, delta: u32) c.struct_compress_res {
    return switch (compressor) {
        .vbyte => c.compress_int_vbyte_unpack_block_d1(@ptrCast(blocks.ptr), bytes.ptr, docs.ptr, len, delta),
        .bp128 => c.compress_int_bp128_unpack_block_d1(@ptrCast(blocks.ptr), bytes.ptr, docs.ptr, len, delta),
        else => unreachable,
    };
}
