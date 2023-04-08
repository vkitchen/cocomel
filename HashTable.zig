//	HASH_TABLE.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const Posting = struct {
    term: []const u8,
    ids: std.ArrayList(u32),
};

cap: u32,
len: u32,
store: []?*Posting,

fn hash(key: []const u8, cap: u32) u32 {
    var result: u32 = 0;

    for (key) |c|
        result = c +% 31 *% result;

    return result & cap - 1;
}

pub fn init(allocator: std.mem.Allocator) !@This() {
    var h: @This() = undefined;
    h.cap = 1 << 16;
    h.len = 0;
    h.store = try allocator.alloc(?*Posting, h.cap);
    std.mem.set(?*Posting, h.store, null);
    return h;
}

fn expand(h: *@This(), allocator: std.mem.Allocator) !void {
    std.debug.print("{s}\n", .{"Expanding table"});
    var new_cap = h.cap << 1;
    var new_store = try allocator.alloc(?*Posting, new_cap);
    std.mem.set(?*Posting, new_store, null);

    var i: u32 = 0;
    while (i < h.cap) : (i += 1) {
        if (h.store[i] != null) {
            var i_ = hash(h.store[i].?.term, new_cap);
            while (new_store[i_] != null)
                i_ = i_ + 1 & new_cap - 1;

            new_store[i_] = h.store[i];
        }
    }

    allocator.free(h.store);
    h.cap = new_cap;
    h.store = new_store;
    std.debug.print("{s}\n", .{"Expanded"});
}

pub fn insert(h: *@This(), allocator: std.mem.Allocator, key: []const u8, doc_id: u32) !void {
    if (h.len > h.cap / 2)
        try h.expand(allocator);

    var i = hash(key, h.cap);
    while (h.store[i] != null) {
        if (std.mem.eql(u8, h.store[i].?.term, key)) {
            try h.store[i].?.ids.append(doc_id);
            return;
        }
        i = i + 1 & (h.cap - 1);
    }

    h.store[i] = try allocator.create(Posting);
    h.store[i].?.ids = std.ArrayList(u32).init(allocator);
    h.store[i].?.term = key;
    try h.store[i].?.ids.append(doc_id);
    h.len += 1;
}
