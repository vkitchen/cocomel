// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const config = @import("config.zig");
const Heap = @import("heap.zig");
const Tournament = @import("tournament.zig");
const TopKTree = @import("top_k_tree.zig").TopKTree;

pub const TopK = if (std.mem.eql(u8, config.top_k, "heap")) blk: {
    break :blk TopKTree(Heap);
} else if (std.mem.eql(u8, config.top_k, "tournament")) blk: {
    break :blk TopKTree(Tournament);
} else {
    @compileError(std.fmt.comptimePrint("Unknown top-k implementation {s}", .{config.top_k}));
};
