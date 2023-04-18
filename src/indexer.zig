//	INDEXER.ZIG
//	-----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("Doc.zig");
const serialise = @import("serialise_ccml.zig");
const stem = @import("stem.zig").stem;
const str = @import("str.zig");

pub const Indexer = struct {
    const Self = @This();

    buffer: [100]u8 = undefined,
    allocator: std.mem.Allocator,
    doc_ids: std.ArrayList(Doc),
    dict: Dictionary,
    snippets_indices: std.ArrayList(u32),
    snippets_file: std.fs.File,
    snippets_buf: std.io.BufferedWriter(4096, std.fs.File.Writer),
    snippets_written: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) !Self {
        const snippets_file = try std.fs.cwd().createFile(config.files.snippets, .{});
        var snippets_buf = std.io.bufferedWriter(snippets_file.writer());

        return .{
            .allocator = allocator,
            .doc_ids = std.ArrayList(Doc).init(allocator),
            .dict = try Dictionary.init(allocator),
            .snippets_indices = std.ArrayList(u32).init(allocator),
            .snippets_file = snippets_file,
            .snippets_buf = snippets_buf,
        };
    }

    pub fn addTerm(self: *Self, term: []u8) !void {
        try self.snippets_buf.writer().writeAll(term);
        try self.snippets_buf.writer().writeByte(' ');
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

    pub fn write(self: *Self) !void {
        try self.flush();

        std.debug.print("{s}\n", .{"Writing index..."});

        const index_file = try std.fs.cwd().createFile(config.files.index, .{});
        var index_buf = std.io.bufferedWriter(index_file.writer());

        const bytes_written = try serialise.write(index_buf.writer(), &self.doc_ids, &self.dict, &self.snippets_indices);

        std.debug.print("Index is {d}B\n", .{bytes_written});
        try self.snippets_buf.flush();
        try index_buf.flush();

        self.snippets_file.close();
        index_file.close();
    }
};
