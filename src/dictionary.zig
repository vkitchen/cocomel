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

// TODO this probably doesn't belong here
pub const Doc = struct {
    name: []u8,
    len: u32 = 0,
};

// TODO this almost certainly doesn't belong here
pub const Manager = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    doc_ids: *std.ArrayList(Doc),
    dict: *Dictionary,
    snippets_writer: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer,
    snippets_indices: std.ArrayList(u32),
    snippets_written: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, doc_ids: *std.ArrayList(Doc), dict: *Dictionary, snippets_writer: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer) Self {
        return .{
            .allocator = allocator,
            .doc_ids = doc_ids,
            .dict = dict,
            .snippets_writer = snippets_writer,
            .snippets_indices = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn addTerm(m: *Self, term: []u8) !void {
        try m.snippets_writer.writeAll(term);
        try m.snippets_writer.writeByte(' ');
        m.snippets_written += @truncate(u32, term.len + 1);

        _ = std.ascii.lowerString(term, term);
        var term_ = str.stripPunct(term, term);
        term_ = stem(term_);

        try m.dict.insert(m.allocator, term_, @truncate(u32, m.doc_ids.items.len - 1));
        m.doc_ids.items[m.doc_ids.items.len - 1].len += 1;
    }

    pub fn addDocId(m: *Self, doc_id: []u8) !void {
        try m.snippets_indices.append(m.snippets_written);

        try m.doc_ids.append(.{ .name = doc_id });
        if (m.doc_ids.items.len % 10000 == 0)
            std.debug.print("{d} Documents\n", .{m.doc_ids.items.len});
    }

    pub fn flush(m: *Self) !void {
        try m.snippets_indices.append(m.snippets_written);
    }
};

pub const Posting = struct {
    term: []u8,
    id: u32 = 0,
    ids: std.ArrayList(u32),
    freqs: std.ArrayList(u8),
};

pub const Dictionary = struct {
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
        h.store[i].?.term = try str.dup(allocator, key);

        h.store[i].?.ids = std.ArrayList(u32).init(allocator);
        try h.store[i].?.ids.append(doc_id);

        h.store[i].?.freqs = std.ArrayList(u8).init(allocator);
        try h.store[i].?.freqs.append(1);

        h.len += 1;
    }
};
