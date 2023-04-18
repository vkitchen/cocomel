//	DICTIONARY.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const str = @import("str.zig");
const stem = @import("stem.zig").stem;

pub fn hash(key: []const u8, cap: u32) u32 {
    var result: u32 = 0;

    for (key) |c|
        result = c +% 31 *% result;

    return result & cap - 1;
}

pub const Posting = struct {
    term: []u8,
    id: u32 = 0,
    ids: std.ArrayList(u32),
    freqs: std.ArrayList(u8),
};

pub const Dictionary = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    cap: u32 = 1 << 19,
    len: u32 = 0,
    store: []?*Posting,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var store = try allocator.alloc(?*Posting, 1 << 19);
        std.mem.set(?*Posting, store, null);
        return .{ .allocator = allocator, .store = store };
    }

    fn expand(self: *Self) !void {
        var new_cap = self.cap << 1;
        var new_store = try self.allocator.alloc(?*Posting, new_cap);
        std.mem.set(?*Posting, new_store, null);

        for (self.store) |p| {
            if (p != null) {
                var i = hash(p.?.term, new_cap);
                while (new_store[i] != null)
                    i = i + 1 & new_cap - 1;

                new_store[i] = p;
            }
        }

        self.allocator.free(self.store);
        self.cap = new_cap;
        self.store = new_store;
    }

    pub fn insert(self: *Self, key: []const u8, doc_id: u32) !void {
        if (self.len > self.cap / 2)
            try self.expand();

        var i = hash(key, self.cap);
        while (self.store[i] != null) {
            if (std.mem.eql(u8, self.store[i].?.term, key)) {
                if (self.store[i].?.ids.items[self.store[i].?.ids.items.len - 1] == doc_id) {
                    self.store[i].?.freqs.items[self.store[i].?.freqs.items.len - 1] +|= 1;
                    return;
                }
                try self.store[i].?.ids.append(doc_id);
                try self.store[i].?.freqs.append(1);
                return;
            }
            i = i + 1 & (self.cap - 1);
        }

        self.store[i] = try self.allocator.create(Posting);
        self.store[i].?.term = try str.dup(self.allocator, key);

        self.store[i].?.ids = std.ArrayList(u32).init(self.allocator);
        try self.store[i].?.ids.append(doc_id);

        self.store[i].?.freqs = std.ArrayList(u8).init(self.allocator);
        try self.store[i].?.freqs.append(1);

        self.len += 1;
    }
};
