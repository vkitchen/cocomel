// POSTINGS.ZIG
// ------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const vbyte = @import("compress_int_vbyte.zig");

pub const Postings = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    term: []u8,
    df_t: u32 = 0,
    id: u32,
    last_id: u32 = 0,
    freq: u8 = 1,
    ids: std.ArrayList(u8) = .empty,
    tfs: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator, term: []u8, id: u32) Self {
        return .{ .allocator = allocator, .term = term, .id = id };
    }

    pub fn flush(self: *Self) !void {
        try self.ids.ensureUnusedCapacity(self.allocator, 5);
        const last = self.ids.items.len;
        self.ids.items.len += vbyte.spaceRequired(self.id - self.last_id);
        _ = vbyte.store(self.ids.items[last..], self.id - self.last_id);
        try self.tfs.append(self.allocator, self.freq);
        self.last_id = self.id;
        self.df_t += 1;
        self.freq = 1;
    }
};
