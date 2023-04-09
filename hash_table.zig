//	HASH_TABLE.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const Posting = struct {
    term: []const u8,
    ids: std.ArrayList(u32),
};

fn hash(key: []const u8, cap: u32) u32 {
    var result: u32 = 0;

    for (key) |c|
        result = c +% 31 *% result;

    return result & cap - 1;
}

pub const HashTable = struct {
    const Self = @This();

    cap: u32,
    len: u32,
    store: []?*Posting,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var h: Self = undefined;
        h.cap = 1 << 16;
        h.len = 0;
        h.store = try allocator.alloc(?*Posting, h.cap);
        std.mem.set(?*Posting, h.store, null);
        return h;
    }

    fn expand(h: *Self, allocator: std.mem.Allocator) !void {
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

    pub fn insert(h: *Self, allocator: std.mem.Allocator, key: []const u8, doc_id: u32) !void {
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

    pub fn write(h: *Self, out: anytype, bytes_written: *u32) !u32 {
        var i: u32 = 0;

        // Write contents
        while (i < h.cap) : (i += 1) {
            if (h.store[i] != null) {
                const posting = h.store[i].?;

                const term_offset = bytes_written.*;
                try out.writeIntNative(u32, @truncate(u32, posting.term.len));
                bytes_written.* += @sizeOf(u32);
                try out.writeAll(posting.term);
                bytes_written.* += @truncate(u32, posting.term.len);

                const ids_offset = bytes_written.*;
                try out.writeIntNative(u32, @truncate(u32, posting.ids.items.len));
                bytes_written.* += @sizeOf(u32);
                for (posting.ids.items) |id| {
                    try out.writeIntNative(u32, id);
                    bytes_written.* += @sizeOf(u32);
                }

                try out.writeIntNative(u32, term_offset);
                try out.writeIntNative(u32, ids_offset);
                h.store[i] = @intToPtr(*Posting, bytes_written.*);
                bytes_written.* += @sizeOf(u32) * 2;
            }
        }

        // Write table
        const table_offset = bytes_written.*;
        try out.writeIntNative(u32, h.cap);
        bytes_written.* += @sizeOf(u32);

        i = 0;
        while (i < h.cap) : (i += 1) {
            try out.writeIntNative(u32, @truncate(u32, @ptrToInt(h.store[i].?)));
            bytes_written.* += @sizeOf(u32);
        }

        return table_offset;
    }
};

pub fn find(index: []const u8, offset: u32, key: []const u8) []const u8 {
    const cap = std.mem.bytesToValue(u32, index[offset .. offset + @sizeOf(u32)][0..4]);
    const table = offset + @sizeOf(u32);
    const posting_offset = table + hash(key, cap) * @sizeOf(u32);

    const posting = std.mem.bytesToValue(u32, index[posting_offset .. posting_offset + @sizeOf(u32)][0..4]);
    // const ids_offset = std.mem.bytesToValue(u32, index[posting_offset + 4 .. posting_offset + 8][0..4]);
    const term = std.mem.bytesToValue(u32, index[posting .. posting + @sizeOf(u32)][0..4]);
    const term_length = std.mem.bytesToValue(u32, index[term .. term + @sizeOf(u32)][0..4]);
    const term_string = term + @sizeOf(u32);
    return index[term_string .. term_string + term_length];
}
