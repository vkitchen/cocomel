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

    allocator: std.mem.Allocator,
    doc_ids: std.ArrayList(Doc),
    dict: Dictionary,
    snippets_indices: std.ArrayList(u32),
    snippets_writer: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer,
    snippets_written: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, snippets_writer: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer) !Self {
        return .{
            .allocator = allocator,
            .doc_ids = std.ArrayList(Doc).init(allocator),
            .dict = try Dictionary.init(allocator),
            .snippets_indices = std.ArrayList(u32).init(allocator),
            .snippets_writer = snippets_writer,
        };
    }

    pub fn addTerm(self: *Self, term: []u8) !void {
        try self.snippets_writer.writeAll(term);
        try self.snippets_writer.writeByte(' ');
        self.snippets_written += @truncate(u32, term.len + 1);

        _ = std.ascii.lowerString(term, term);
        var term_ = str.stripPunct(term, term);
        term_ = stem(term_);

        try self.dict.insert(term_, @truncate(u32, self.doc_ids.items.len - 1));
        self.doc_ids.items[self.doc_ids.items.len - 1].len += 1;
    }

    pub fn addDocId(self: *Self, doc_id: []u8) !void {
        try self.snippets_indices.append(self.snippets_written);

        try self.doc_ids.append(.{ .name = try str.dup(self.allocator, doc_id) });
        if (self.doc_ids.items.len % 10000 == 0)
            std.debug.print("{d} Documents\n", .{self.doc_ids.items.len});
    }

    fn flush(self: *Self) !void {
        try self.snippets_indices.append(self.snippets_written);
    }

    pub fn write(self: *Self, buf: std.io.BufferedWriter(4096, std.fs.File.Writer).Writer) !void {
        try self.flush();

        std.debug.print("{s}\n", .{"Writing index..."});

        const bytes_written = try serialise.write(buf, &self.doc_ids, &self.dict, &self.snippets_indices);

        std.debug.print("Index is {d}B\n", .{bytes_written});
    }
};
