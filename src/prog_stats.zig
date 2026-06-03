// PROG_STATS.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Index = @import("index.zig").Index;

pub fn main(init: std.process.Init) !void {
    const index_file = try std.Io.Dir.cwd().readFileAlloc(init.io, config.index_name, init.arena.allocator(), std.Io.Limit.unlimited);
    const index = try Index.init(init.arena.allocator(), index_file);

    std.debug.print("Docs: {d}\n", .{ index.docs_count });
}
