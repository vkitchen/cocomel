// SERIALISER_CCML.ZIG
// -------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
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

    fn writeDictionary(self: *Self, allocator: std.mem.Allocator, h: *Dictionary, bytes_written: *u32) !u32 {
        const offsets = try allocator.alloc([2]u32, h.cap);
        @memset(offsets, .{ 0, 0 });

        // Write contents
        for (h.store, 0..) |p, hi| {
            if (p != null) {
                const posting = p.?;
                try posting.flush();

                const term_offset = bytes_written.*;
                try self.writer.interface.writeInt(u16, @truncate(posting.term.len), native_endian);
                try self.writer.interface.writeAll(posting.term);
                bytes_written.* += @sizeOf(u16) + @as(u32, @truncate(posting.term.len));

                // df_t
                const ids_offset = bytes_written.*;
                try self.writer.interface.writeInt(u32, @truncate(posting.df_t), native_endian);
                bytes_written.* += @sizeOf(u32);
                // postings chunks
                var i: u8 = 255;
                while (i > 0) : (i -= 1) {
                    if (posting.ids[i - 1] == null)
                        continue;
                    const postings_list = posting.ids[i - 1].?;
                    try self.writer.interface.writeInt(u32, @truncate(postings_list.items.len), native_endian);
                    try self.writer.interface.writeInt(u8, i, native_endian);
                    try self.writer.interface.writeAll(postings_list.items);
                    bytes_written.* += @sizeOf(u32) + @sizeOf(u8) + @as(u32, @truncate(postings_list.items.len));
                }
                // If there is no impact 1 write a dummy postings list
                if (posting.ids[0] == null) {
                    try self.writer.interface.writeInt(u32, 0, native_endian);
                    bytes_written.* += @sizeOf(u32);
                }

                offsets[hi][0] = term_offset;
                offsets[hi][1] = ids_offset;
            }
        }

        // Write table
        const table_offset = bytes_written.*;
        try self.writer.interface.writeInt(u32, h.cap, native_endian);
        bytes_written.* += @sizeOf(u32);

        for (offsets) |p| {
            try self.writer.interface.writeInt(u32, p[0], native_endian);
            try self.writer.interface.writeInt(u32, p[1], native_endian);
            bytes_written.* += 2 * @sizeOf(u32);
        }

        std.debug.print("Terms count {d}\n", .{h.len});

        return table_offset;
    }

    pub fn write(self: *Self, allocator: std.mem.Allocator, docs: *std.ArrayList(Doc), dictionary: *Dictionary) !u32 {
        // Flush snippets
        try self.newDocId(allocator);

        var bytes_written: u32 = @truncate(self.writer.logicalPos());

        // Document ID strings
        for (docs.items, 0..) |d, i| {
            try self.writer.interface.writeInt(u32, d.len, native_endian);
            try self.writer.interface.writeInt(u16, @truncate(d.name.len), native_endian);
            try self.writer.interface.writeAll(d.name);
            if (d.title) |title| {
                try self.writer.interface.writeInt(u16, @truncate(title.len), native_endian);
                try self.writer.interface.writeAll(title);
            } else {
                try self.writer.interface.writeInt(u16, 0, native_endian);
            }
            docs.items[i].name.ptr = @ptrFromInt(bytes_written);
            bytes_written += @sizeOf(u32) + @sizeOf(u16) + @as(u32, @truncate(d.name.len)) + @sizeOf(u16);
            if (d.title) |title|
                bytes_written += @truncate(title.len);
        }

        // Document IDs array
        const docs_offset = bytes_written;
        for (docs.items) |d| {
            try self.writer.interface.writeInt(u32, @truncate(@intFromPtr(d.name.ptr)), native_endian);
            bytes_written += @sizeOf(u32);
        }

        // Dictionary
        const dictionary_offset = try self.writeDictionary(allocator, dictionary, &bytes_written);

        // Snippets
        const snippets_offset = bytes_written;
        for (self.snippet_indices.items) |s| {
            try self.writer.interface.writeInt(u32, s, native_endian);
            bytes_written += @sizeOf(u32);
        }

        // Metadata
        try self.writer.interface.writeInt(u32, @truncate(docs.items.len), native_endian);
        try self.writer.interface.writeInt(u32, docs_offset, native_endian);
        try self.writer.interface.writeInt(u32, dictionary_offset, native_endian);
        try self.writer.interface.writeInt(u32, snippets_offset, native_endian);
        bytes_written += 4 * @sizeOf(u32);

        // Config
        try self.writer.interface.writeByte(0); // padding
        try self.writer.interface.writeByte(if (self.snippets) 1 else 0);
        try self.writer.interface.writeInt(u16, config.index_version, native_endian);
        bytes_written += 4;

        try self.writer.flush();

        return bytes_written;
    }
};
