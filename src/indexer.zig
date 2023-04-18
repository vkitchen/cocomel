//	INDEXER.ZIG
//	-----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("Doc.zig");
const serialise = @import("serialise_ccml.zig");
const stem = @import("stem.zig").stem;
const str = @import("str.zig");

pub const Indexer = struct {
    const Self = @This();

    doc_ids: std.ArrayList(Doc),
    dict: Dictionary,
    snippets_indices: std.ArrayList(u32),
    snippets_writer: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer,
    snippets_written: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, snippets_writer: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer) !Self {
        return .{
            .doc_ids = std.ArrayList(Doc).init(allocator),
            .dict = try Dictionary.init(allocator),
            .snippets_indices = std.ArrayList(u32).init(allocator),
            .snippets_writer = snippets_writer,
        };
    }

    pub fn addTerm(m: *Self, term: []u8) !void {
        try m.snippets_writer.writeAll(term);
        try m.snippets_writer.writeByte(' ');
        m.snippets_written += @truncate(u32, term.len + 1);

        _ = std.ascii.lowerString(term, term);
        var term_ = str.stripPunct(term, term);
        term_ = stem(term_);

        try m.dict.insert(term_, @truncate(u32, m.doc_ids.items.len - 1));
        m.doc_ids.items[m.doc_ids.items.len - 1].len += 1;
    }

    pub fn addDocId(m: *Self, doc_id: []u8) !void {
        try m.snippets_indices.append(m.snippets_written);

        try m.doc_ids.append(.{ .name = doc_id });
        if (m.doc_ids.items.len % 10000 == 0)
            std.debug.print("{d} Documents\n", .{m.doc_ids.items.len});
    }

    fn flush(m: *Self) !void {
        try m.snippets_indices.append(m.snippets_written);
    }

    pub fn write(m: *Self, buf: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer) !void {
        try m.flush();

        std.debug.print("{s}\n", .{"Writing index..."});

        const bytes_written = try serialise.write(buf, &m.doc_ids, &m.dict, &m.snippets_indices);

        std.debug.print("Index is {d}B\n", .{bytes_written});
    }
};
