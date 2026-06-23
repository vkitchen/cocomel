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

const c = @import("c");

const file_format = std.fmt.comptimePrint("cocomel v{d}\n", .{index.version});

var writer_buf: [config.io_buffer_size]u8 = undefined;

pub const CcmlSerialiser = struct {
    const Self = @This();

    file: std.Io.File,
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

        self.writer = file.writer(io, &writer_buf);

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

    // This goes over the index multiple times to avoid allocating excessive memory
    pub fn write(self: *Self, allocator: std.mem.Allocator, docs: *std.ArrayList(Doc), dictionary: *Dictionary, stemmer: Stemmer.Alg, quantise: bool) !u64 {
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

        // Quantise
        if (quantise) {
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

            // Actually quantise now
            const quantiser = Quantiser.init(min_score, max_score);

            for (dictionary.store) |post| {
                if (post == null) continue;

                try post.?.quantise(docs, &ranker, quantiser);
            }
        }

        // Write out the segments themselves
        while (self.writer.logicalPos() % @alignOf(u128) != 0) try self.writer.interface.writeByte(0);
        const segments_start = self.writer.logicalPos();

        const segments_offsets = try allocator.alloc(u64, dictionary.cap);
        @memset(segments_offsets, 0);

        var doc_ids = [_]std.ArrayList(u32){.empty} ** (1 << config.quantise_bits);
        for (&doc_ids) |*d| try d.resize(allocator, docs.items.len); // reserve so arena doesn't get trampled

        const compression_buffer = try allocator.alloc(u8, docs.items.len * @sizeOf(u32));

        for (dictionary.store, 0..) |postings, i| {
            if (postings == null) continue;

            for (&doc_ids) |*d| d.clearRetainingCapacity();

            try postings.?.distribute(&doc_ids);

            segments_offsets[i] = self.writer.logicalPos() - segments_start;

            // Write segments (these must be aligned)
            var impact: index.ImpactType = (1 << config.quantise_bits) - 1;
            while (impact > 0) : (impact -= 1) {
                if (doc_ids[impact].items.len == 0)
                    continue;

                const bytes_written = c.compress_int_pack(doc_ids[impact].items.ptr, doc_ids[impact].items.len, compression_buffer.ptr);
                try self.writer.interface.writeAll(compression_buffer[0..bytes_written]);
            }
        }

        const segments_end = self.writer.logicalPos();

        // Write out dictionary terms and segments metadata
        const dictionary_offsets = try allocator.alloc(u64, dictionary.cap);
        @memset(dictionary_offsets, 0);

        for (dictionary.store, 0..) |postings, i| {
            if (postings == null) continue;

            for (&doc_ids) |*d| d.clearRetainingCapacity();

            try postings.?.distribute(&doc_ids);

            // Write postings
            dictionary_offsets[i] = self.writer.logicalPos();
            try self.writeStr(postings.?.term);

            // Store the segment offset
            try self.writer.interface.writeInt(u64, segments_offsets[i], native_endian);

            // Write segments metadata
            var impact: index.ImpactType = (1 << config.quantise_bits) - 1;
            while (impact > 0) : (impact -= 1) {
                if (doc_ids[impact].items.len == 0)
                    continue;

                // Store the segment metada
                try self.writer.interface.writeInt(index.ImpactType, impact, native_endian);
                // no. docs
                var vbyte_buffer: [5]u8 = undefined;
                const segment_len = vbyte.store(&vbyte_buffer, @truncate(doc_ids[impact].items.len));
                try self.writer.interface.writeAll(vbyte_buffer[0..segment_len]);
                // selectors
                const bytes_written = c.compress_int_pack_selectors(doc_ids[impact].items.ptr, doc_ids[impact].items.len, compression_buffer.ptr);
                try self.writer.interface.writeAll(compression_buffer[0..bytes_written]);
            }
            // Null terminate
            try self.writer.interface.writeInt(index.ImpactType, 0, native_endian);
        }

        // Dictionary
        while (self.writer.logicalPos() % @alignOf(u64) != 0) try self.writer.interface.writeByte(0);
        const dictionary_offset = self.writer.logicalPos();
        try self.writer.interface.writeInt(u64, dictionary.cap, native_endian);
        try self.writer.interface.writeSliceEndian(u64, dictionary_offsets, native_endian);

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

        // Header
        while (self.writer.logicalPos() % @alignOf(index.Header) != 0) try self.writer.interface.writeByte(0);
        try self.writer.interface.writeStruct(index.Header{
            .max_doc_length = max_doc_length,
            .snippets_offset = snippets_offset,
            .segments_start = segments_start,
            .segments_end = segments_end,
            .dictionary_offset = dictionary_offset,
            .docs_offset = docs_offset,
            .stemmer = stemmer,
            .version = index.version,
        }, native_endian);

        try self.writer.flush();

        return self.writer.logicalPos();
    }
};
