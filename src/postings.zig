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
    freq: u8 = 1,
    id: u32,
    // Freq 1 - 255 (shifted for 0 indexing)
    ids: [255]?*std.ArrayList(u8) = [_]?*std.ArrayList(u8){null} ** 255,
    last_ids: [255]u32 = [_]u32{0} ** 255,

    pub fn init(allocator: std.mem.Allocator, term: []u8, id: u32) Self {
        return .{ .allocator = allocator, .term = term, .id = id };
    }

    pub fn flush(self: *Self) !void {
        const index = self.freq - 1;
        if (self.ids[index] == null) {
            self.ids[index] = try self.allocator.create(std.ArrayList(u8));
            self.ids[index].?.* = try std.ArrayList(u8).initCapacity(self.allocator, 8);
        }
        var postings = self.ids[index].?;
        try postings.ensureUnusedCapacity(self.allocator, 5);
        const last = postings.items.len;
        postings.items.len += vbyte.spaceRequired(self.id - self.last_ids[index]);
        _ = vbyte.store(postings.items[last..], self.id - self.last_ids[index]);
        self.last_ids[index] = self.id;
        self.df_t += 1;
        self.freq = 1;
    }
};
