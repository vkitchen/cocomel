//	DICTIONARY.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const Posting = struct {
    term: []u8,
    ids: std.ArrayList(u32),
    freqs: std.ArrayList(u8),
};

pub fn hash(key: []const u8, cap: u32) u32 {
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
        h.cap = 1 << 19;
        h.len = 0;
        h.store = try allocator.alloc(?*Posting, h.cap);
        std.mem.set(?*Posting, h.store, null);
        return h;
    }

    fn expand(h: *Self, allocator: std.mem.Allocator) !void {
        var new_cap = h.cap << 1;
        var new_store = try allocator.alloc(?*Posting, new_cap);
        std.mem.set(?*Posting, new_store, null);

        for (h.store) |p| {
            if (p != null) {
                var i = hash(p.?.term, new_cap);
                while (new_store[i] != null)
                    i = i + 1 & new_cap - 1;

                new_store[i] = p;
            }
        }

        allocator.free(h.store);
        h.cap = new_cap;
        h.store = new_store;
    }

    pub fn insert(h: *Self, allocator: std.mem.Allocator, key: []const u8, doc_id: u32) !void {
        if (h.len > h.cap / 2)
            try h.expand(allocator);

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

        h.store[i] = try allocator.create(Posting);
        h.store[i].?.term = try allocator.alloc(u8, key.len);
        std.mem.copy(u8, h.store[i].?.term, key);

        h.store[i].?.ids = std.ArrayList(u32).init(allocator);
        try h.store[i].?.ids.append(doc_id);

        h.store[i].?.freqs = std.ArrayList(u8).init(allocator);
        try h.store[i].?.freqs.append(1);

        h.len += 1;
    }

    pub fn write(h: *Self, out: anytype, bytes_written: *u32) !u32 {
        // Write contents
        for (h.store) |p, i| {
            if (p != null) {
                const posting = p.?;

                const term_offset = bytes_written.*;
                try out.writeIntNative(u16, @truncate(u16, posting.term.len));
                bytes_written.* += @sizeOf(u16);
                try out.writeAll(posting.term);
                bytes_written.* += @truncate(u32, posting.term.len);

                const ids_offset = bytes_written.*;
                try out.writeIntNative(u32, @truncate(u32, posting.ids.items.len));
                bytes_written.* += @sizeOf(u32);
                for (posting.ids.items) |id| {
                    try out.writeIntNative(u32, id);
                    bytes_written.* += @sizeOf(u32);
                }

                const freqs_offset = bytes_written.*;
                try out.writeIntNative(u32, @truncate(u32, posting.freqs.items.len));
                bytes_written.* += @sizeOf(u32);
                for (posting.freqs.items) |freq| {
                    try out.writeIntNative(u8, freq);
                    bytes_written.* += @sizeOf(u8);
                }

                try out.writeIntNative(u32, term_offset);
                try out.writeIntNative(u32, ids_offset);
                try out.writeIntNative(u32, freqs_offset);
                h.store[i] = @intToPtr(*Posting, bytes_written.*);
                bytes_written.* += @sizeOf(u32) * 3;
            }
        }

        // Write table
        const table_offset = bytes_written.*;
        try out.writeIntNative(u32, h.cap);
        bytes_written.* += @sizeOf(u32);

        for (h.store) |p| {
            try out.writeIntNative(u32, @truncate(u32, @ptrToInt(p.?)));
            bytes_written.* += @sizeOf(u32);
        }

        std.debug.print("Terms count {d}\n", .{h.len});

        return table_offset;
    }
};
