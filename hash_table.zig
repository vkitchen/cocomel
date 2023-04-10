//	HASH_TABLE.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const Posting = struct {
    term: []const u8,
    ids: std.ArrayList(u32),
    freqs: std.ArrayList(u8),
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
                if (h.store[i].?.ids.items[h.store[i].?.ids.items.len - 1] == doc_id) {
                    if (h.store[i].?.freqs.items[h.store[i].?.freqs.items.len - 1] == 255)
                        return;
                    h.store[i].?.freqs.items[h.store[i].?.freqs.items.len - 1] += 1;
                    return;
                }
                try h.store[i].?.ids.append(doc_id);
                try h.store[i].?.freqs.append(1);
                return;
            }
            i = i + 1 & (h.cap - 1);
        }

        h.store[i] = try allocator.create(Posting);
        h.store[i].?.term = key;

        h.store[i].?.ids = std.ArrayList(u32).init(allocator);
        try h.store[i].?.ids.append(doc_id);

        h.store[i].?.freqs = std.ArrayList(u8).init(allocator);
        try h.store[i].?.freqs.append(1);

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

        i = 0;
        while (i < h.cap) : (i += 1) {
            try out.writeIntNative(u32, @truncate(u32, @ptrToInt(h.store[i].?)));
            bytes_written.* += @sizeOf(u32);
        }

        std.debug.print("Terms count {d}\n", .{h.len});

        return table_offset;
    }
};

fn top10(index: []const u8, offset: u32) [11]u32 {
    const ids_offset = std.mem.bytesToValue(u32, index[offset .. offset + @sizeOf(u32)][0..4]);
    const ids_len = std.mem.bytesToValue(u32, index[ids_offset .. ids_offset + @sizeOf(u32)][0..4]);
    var out: [11]u32 = undefined;
    out[0] = std.math.min(10, ids_len);

    var i: u32 = 0;
    while (i < out[0]) : (i += 1) {
        const stride = (i + 1) * @sizeOf(u32);
        out[i + 1] = std.mem.bytesToValue(u32, index[ids_offset + stride .. ids_offset + stride + @sizeOf(u32)][0..4]);
    }

    return out;
}

pub fn find(index: []const u8, offset: u32, key: []const u8) ?[11]u32 {
    const cap = std.mem.bytesToValue(u32, index[offset .. offset + @sizeOf(u32)][0..4]);
    const table = offset + @sizeOf(u32);

    var i = hash(key, cap);
    while (true) {
        const posting_offset = table + i * @sizeOf(u32);

        const posting = std.mem.bytesToValue(u32, index[posting_offset .. posting_offset + @sizeOf(u32)][0..4]);
        if (posting == 0)
            return null;
        const term_store = std.mem.bytesToValue(u32, index[posting .. posting + @sizeOf(u32)][0..4]);
        const term_length = std.mem.bytesToValue(u32, index[term_store .. term_store + @sizeOf(u32)][0..4]);
        const term_start = term_store + @sizeOf(u32);
        const term = index[term_start .. term_start + term_length];
        if (std.mem.eql(u8, term, key))
            return top10(index, posting + @sizeOf(u32));

        i = i + 1 & (cap - 1);
    }
}
