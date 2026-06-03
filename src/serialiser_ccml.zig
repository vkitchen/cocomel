// SERIALISER_CCML.ZIG
// -------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const index = @import("index.zig");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("Doc.zig");
const Posting = @import("dictionary.zig").Posting;
const native_endian = @import("builtin").target.cpu.arch.endian();

const file_format = std.fmt.comptimePrint("cocomel v{d}\n", .{config.index_version});

pub const CcmlSerialiser = struct {
    const Self = @This();

    file: std.Io.File,
    writer_buf: [config.io_buffer_size]u8 = undefined,
    writer: std.Io.File.Writer,
    snippet_indices: std.ArrayList(u32) = .empty,
    snippets: bool,

    pub fn init(io: std.Io, snippets: bool) !Self {
        const file = try std.Io.Dir.cwd().createFile(io, config.index_name, .{});

        var self = Self{
            .file = file,
            .writer = undefined,
            .snippets = snippets,
        };

        self.writer = file.writer(io, &self.writer_buf);

        // Write header
        try self.writer.interface.writeAll(file_format);

        return self;
    }

    pub fn addSnippetTerm(self: *Self, term: []u8) !void {
        if (!self.snippets) return;
        try self.writer.interface.writeAll(term);
        try self.writer.interface.writeByte(' ');
    }

    pub fn newDocId(self: *Self, allocator: std.mem.Allocator) !void {
        if (!self.snippets) return;
        try self.snippet_indices.append(allocator, @truncate(self.writer.logicalPos()));
    }

    fn writeStr(self: *Self, str: []u8) !void {
        try self.writer.interface.writeInt(u16, @truncate(str.len), native_endian);
        try self.writer.interface.writeAll(str);
    }

    fn writeDictionary(self: *Self, allocator: std.mem.Allocator, h: *Dictionary) !u64 {
        const offsets = try allocator.alloc([2]u32, h.cap);
        @memset(offsets, .{ 0, 0 });

        // Write contents
        for (h.store, 0..) |p, hi| {
            if (p != null) {
                const posting = p.?;
                try posting.flush();

                const term_offset = self.writer.logicalPos();
                try self.writeStr(posting.term);

                // df_t
                const ids_offset = self.writer.logicalPos();
                try self.writer.interface.writeInt(u32, @truncate(posting.df_t), native_endian);
                // postings chunks
                var i: u8 = 255;
                while (i > 0) : (i -= 1) {
                    if (posting.ids[i - 1] == null)
                        continue;
                    const postings_list = posting.ids[i - 1].?;
                    try self.writer.interface.writeInt(u32, @truncate(postings_list.items.len), native_endian);
                    try self.writer.interface.writeInt(u8, i, native_endian);
                    try self.writer.interface.writeAll(postings_list.items);
                }
                // If there is no impact 1 write a dummy postings list
                if (posting.ids[0] == null)
                    try self.writer.interface.writeInt(u32, 0, native_endian);

                offsets[hi][0] = @truncate(term_offset);
                offsets[hi][1] = @truncate(ids_offset);
            }
        }

        // Write table
        const table_offset = self.writer.logicalPos();
        try self.writer.interface.writeInt(u32, h.cap, native_endian);

        for (offsets) |p| {
            try self.writer.interface.writeInt(u32, p[0], native_endian);
            try self.writer.interface.writeInt(u32, p[1], native_endian);
        }

        std.debug.print("Terms count {d}\n", .{h.len});

        return table_offset;
    }

    pub fn write(self: *Self, allocator: std.mem.Allocator, docs: *std.ArrayList(Doc), dictionary: *Dictionary) !u64 {
        // Flush snippets
        try self.newDocId(allocator);

        // Snippets
        const snippets_offset = if (self.snippets) self.writer.logicalPos() else 0;
        for (self.snippet_indices.items) |s|
            try self.writer.interface.writeInt(u32, s, native_endian);

        // Document ID strings
        for (docs.items, 0..) |d, i| {
            const name_offset = self.writer.logicalPos();
            try self.writer.interface.writeInt(u32, d.len, native_endian);
            try self.writeStr(d.name);
            try self.writeStr(d.title);
            docs.items[i].name.ptr = @ptrFromInt(name_offset);
        }

        // Document IDs array
        const docs_offset = self.writer.logicalPos();
        for (docs.items) |d|
            try self.writer.interface.writeInt(u32, @truncate(@intFromPtr(d.name.ptr)), native_endian);

        // Dictionary
        const dictionary_offset = try self.writeDictionary(allocator, dictionary);

        // Header
        try self.writer.interface.writeStruct(index.Header{
            .docs_count = @truncate(docs.items.len),
            .docs_offset = @truncate(docs_offset),
            .dictionary_offset = @truncate(dictionary_offset),
            .snippets_offset = @truncate(snippets_offset),
            .version = config.index_version,
        }, native_endian);

        try self.writer.flush();

        return self.writer.logicalPos();
    }
};
