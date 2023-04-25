//	DICTIONARY.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const str = @import("str.zig");
const stem = @import("stem.zig").stem;
const vbyte = @import("compress_int_vbyte.zig");

pub fn hash(key: []const u8, cap: u32) u32 {
    var result: u32 = 0;

    for (key) |c|
        result = c +% 31 *% result;

    return result & cap - 1;
}

pub const Posting = struct {
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
        try postings.ensureUnusedCapacity(5);
        const last = postings.items.len;
        postings.items.len += vbyte.spaceRequired(self.id - self.last_ids[index]);
        _ = vbyte.store(postings.items[last..], self.id - self.last_ids[index]);
        self.last_ids[index] = self.id;
        self.df_t += 1;
        self.freq = 1;
    }
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
            var postings = self.store[i].?;
            if (std.mem.eql(u8, postings.term, key)) {
                if (postings.id == doc_id) {
                    postings.freq +|= 1;
                    return;
                }
                try postings.flush();
                postings.id = doc_id;
                return;
            }
            i = i + 1 & (self.cap - 1);
        }

        var postings = try self.allocator.create(Posting);
        postings.* = Posting.init(self.allocator, try str.dup(self.allocator, key), doc_id);

        self.store[i] = postings;

        self.len += 1;
    }
};
