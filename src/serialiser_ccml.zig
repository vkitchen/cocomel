// SERIALISER_CCML.ZIG
// -------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const index = @import("index.zig");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("doc.zig");
const Stemmer = @import("stem.zig").Stemmer;
const Posting = @import("dictionary.zig").Posting;
const Ranker = @import("ranking_fn_bm25.zig").Ranker;
const Quantiser = @import("quantiser.zig").Quantiser;
const vbyte = @import("compress_int_vbyte.zig");
const native_endian = @import("builtin").target.cpu.arch.endian();

const file_format = std.fmt.comptimePrint("cocomel v{d}\n", .{index.version});

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

    pub fn write(self: *Self, allocator: std.mem.Allocator, docs: *std.ArrayList(Doc), dictionary: *Dictionary, stemmer: Stemmer.Alg) !u64 {
        // Flush snippets
        try self.newDocId(allocator);

        // Snippets
        var snippets_offset: u64 = 0;
        if (self.snippets) {
            while (self.writer.logicalPos() % @alignOf(u64) != 0) try self.writer.interface.writeByte(0);
            snippets_offset = self.writer.logicalPos();
            try self.writer.interface.writeInt(u64, self.snippet_indices.items.len, native_endian);
            for (self.snippet_indices.items) |s|
                try self.writer.interface.writeInt(u64, s, native_endian);
        }

        // Find average document length
        var average_doc_length: f64 = 0;

        for (docs.items) |d|
            average_doc_length += @floatFromInt(d.len);
        average_doc_length /= @floatFromInt(docs.items.len);

        var ranker = Ranker.init(@floatFromInt(docs.items.len), average_doc_length);

        // Find minimum and maximum rsv
        var min_score: f64 = std.math.floatMax(f64);
        var max_score: f64 = 0;
        for (dictionary.store) |post| {
            if (post == null) continue;

            const scores = post.?.score(docs, &ranker);

            if (scores[0] < min_score) min_score = scores[0];
            if (scores[1] > max_score) max_score = scores[1];
        }

        const dictionary_offsets = try allocator.alloc(u64, dictionary.cap);
        @memset(dictionary_offsets, 0);

        // Quantise
        var doc_ids = [_]std.ArrayList(u8){.empty} ** (1 << config.quantise_bits);

        const quantiser = Quantiser.init(min_score, max_score);

        for (dictionary.store, 0..) |post, hi| {
            if (post == null) continue;

            for (&doc_ids) |*d| d.clearRetainingCapacity();

            try post.?.quantise(allocator, docs, &ranker, quantiser, &doc_ids);

            // Write postings
            const term_offset = self.writer.logicalPos();
            try self.writeStr(post.?.term);

            // Write chunks
            var i: index.ImpactType = (1 << config.quantise_bits) - 1;
            while (i > 0) : (i -= 1) {
                if (doc_ids[i].items.len == 0)
                    continue;
                try self.writer.interface.writeInt(u32, @truncate(doc_ids[i].items.len), native_endian);
                try self.writer.interface.writeInt(index.ImpactType, i, native_endian);
                try self.writer.interface.writeAll(doc_ids[i].items);
            }
            // Null terminate
            try self.writer.interface.writeInt(u32, 0, native_endian);

            dictionary_offsets[hi] = term_offset;
        }

        // Document ID strings
        var max_doc_length: u32 = 0;
        for (docs.items, 0..) |d, i| {
            if (d.len > max_doc_length) max_doc_length = d.len;
            const name_offset = self.writer.logicalPos();
            try self.writeStr(d.name);
            try self.writeStr(d.title);
            docs.items[i].name.ptr = @ptrFromInt(name_offset);
        }

        // Document IDs array
        while (self.writer.logicalPos() % @alignOf(u64) != 0) try self.writer.interface.writeByte(0);
        const docs_offset = self.writer.logicalPos();
        try self.writer.interface.writeInt(u64, docs.items.len, native_endian);
        for (docs.items) |d|
            try self.writer.interface.writeInt(u64, @intFromPtr(d.name.ptr), native_endian);

        // Dictionary
        while (self.writer.logicalPos() % @alignOf(u64) != 0) try self.writer.interface.writeByte(0);
        const dictionary_offset = self.writer.logicalPos();
        try self.writer.interface.writeInt(u64, dictionary.cap, native_endian);
        try self.writer.interface.writeSliceEndian(u64, dictionary_offsets, native_endian);

        std.debug.print("Terms count {d}\n", .{dictionary.len});

        // Header
        while (self.writer.logicalPos() % @alignOf(index.Header) != 0) try self.writer.interface.writeByte(0);
        try self.writer.interface.writeStruct(index.Header{
            .max_doc_length = max_doc_length,
            .snippets_offset = snippets_offset,
            .docs_offset = docs_offset,
            .dictionary_offset = dictionary_offset,
            .stemmer = stemmer,
            .version = index.version,
        }, native_endian);

        try self.writer.flush();

        return self.writer.logicalPos();
    }
};
