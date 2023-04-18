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

    fn expand(h: *Self) !void {
        var new_cap = h.cap << 1;
        var new_store = try h.allocator.alloc(?*Posting, new_cap);
        std.mem.set(?*Posting, new_store, null);

        for (h.store) |p| {
            if (p != null) {
                var i = hash(p.?.term, new_cap);
                while (new_store[i] != null)
                    i = i + 1 & new_cap - 1;

                new_store[i] = p;
            }
        }

        h.allocator.free(h.store);
        h.cap = new_cap;
        h.store = new_store;
    }

    pub fn insert(h: *Self, key: []const u8, doc_id: u32) !void {
        if (h.len > h.cap / 2)
            try h.expand();

        var i = hash(key, h.cap);
        while (h.store[i] != null) {
            if (std.mem.eql(u8, h.store[i].?.term, key)) {
                if (h.store[i].?.ids.items[h.store[i].?.ids.items.len - 1] == doc_id) {
                    h.store[i].?.freqs.items[h.store[i].?.freqs.items.len - 1] +|= 1;
                    return;
                }
                try h.store[i].?.ids.append(doc_id);
                try h.store[i].?.freqs.append(1);
                return;
            }
            i = i + 1 & (h.cap - 1);
        }

        h.store[i] = try h.allocator.create(Posting);
        h.store[i].?.term = try str.dup(h.allocator, key);

        h.store[i].?.ids = std.ArrayList(u32).init(h.allocator);
        try h.store[i].?.ids.append(doc_id);

        h.store[i].?.freqs = std.ArrayList(u8).init(h.allocator);
        try h.store[i].?.freqs.append(1);

        h.len += 1;
    }
};
