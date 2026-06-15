// DICTIONARY.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Wyhash = std.hash.Wyhash;

const str = @import("str.zig");
const stem = @import("stem.zig").stem;
const Postings = @import("postings.zig").Postings;

pub const Dictionary = struct {
    const Self = @This();

    cap: u32 = 1 << 27,
    len: u32 = 0,
    store: []?*Postings,

    pub fn init(allocator: std.mem.Allocator) !Self {
        const store = try allocator.alloc(?*Postings, 1 << 27);
        @memset(store, null);
        return .{ .store = store };
    }

    fn expand(self: *Self, allocator: std.mem.Allocator) !void {
        const new_cap = self.cap << 1;
        var new_store = try allocator.alloc(?*Postings, new_cap);
        @memset(new_store, null);

        for (self.store) |p| {
            if (p != null) {
                var i = Wyhash.hash(0, p.?.term) & self.cap - 1;
                while (new_store[i] != null)
                    i = i + 1 & new_cap - 1;

                new_store[i] = p;
            }
        }

        allocator.free(self.store);
        self.cap = new_cap;
        self.store = new_store;
    }

    pub fn insert(self: *Self, allocator: std.mem.Allocator, key: []const u8, doc_id: u32) !*Postings {
        if (self.len > self.cap / 2)
            try self.expand(allocator);

        var i = Wyhash.hash(0, key) & self.cap - 1;
        while (self.store[i] != null) {
            var postings = self.store[i].?;
            if (std.mem.eql(u8, postings.term, key)) {
                if (postings.id == doc_id) {
                    postings.freq +|= 1;
                    return postings;
                }
                try postings.flush(allocator);
                postings.id = doc_id;
                return postings;
            }
            i = i + 1 & self.cap - 1;
        }

        const postings = try allocator.create(Postings);
        postings.* = Postings.init(try str.dup(allocator, key), doc_id);

        self.store[i] = postings;

        self.len += 1;

        return postings;
    }
};
