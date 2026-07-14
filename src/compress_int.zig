// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");

const c = @import("c");

pub inline fn pack_stream(blocks: []u128, bytes: []u8, docs: []const u32) c.struct_compress_res {
    return c.compress_int_bp128_pack_stream(@ptrCast(blocks.ptr), bytes.ptr, docs.ptr, docs.len);
}

pub inline fn unpack_block(blocks: []const u128, bytes: []const u8, docs: []u32) c.struct_compress_res {
    return c.compress_int_bp128_unpack_block(@ptrCast(blocks.ptr), bytes.ptr, docs.ptr);
}
