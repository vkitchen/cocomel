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

        const snippets_start: u64 = 0; // TODO this shouldn't include the file opening remark
        const snippets_end: u64 = self.writer.logicalPos();

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
        const blocks_start = self.writer.logicalPos();

        // Block storage is always large so use u64 here
        const segments_offsets = try allocator.alloc(u64, dictionary.cap);
        @memset(segments_offsets, 0);

        var doc_ids = [_]std.ArrayList(u32){.empty} ** (1 << config.quantise_bits);
        for (&doc_ids) |*d| try d.resize(allocator, docs.items.len); // reserve so arena doesn't get trampled

        const compression_buffer = try allocator.alloc(u8, docs.items.len * @sizeOf(u32));

        for (dictionary.store, 0..) |postings, i| {
            if (postings == null) continue;

            for (&doc_ids) |*d| d.clearRetainingCapacity();

            try postings.?.distribute(&doc_ids);

            segments_offsets[i] = self.writer.logicalPos() - blocks_start;

            // Write segments (these must be aligned)
            var impact: index.ImpactType = (1 << config.quantise_bits) - 1;
            while (impact > 0) : (impact -= 1) {
                if (doc_ids[impact].items.len == 0)
                    continue;

                const bytes_written = c.compress_int_pack(doc_ids[impact].items.ptr, doc_ids[impact].items.len, compression_buffer.ptr);
                try self.writer.interface.writeAll(compression_buffer[0..bytes_written]);
            }
        }

        const blocks_end = self.writer.logicalPos();

        // Write out segments metadata
        const vocab_offsets = try allocator.alloc(index.VocabTuple, dictionary.cap);
        @memset(vocab_offsets, .{ .term = 0, .postings = 0 });

        const postings_start = self.writer.logicalPos();

        for (dictionary.store, 0..) |postings, i| {
            if (postings == null) continue;

            for (&doc_ids) |*d| d.clearRetainingCapacity();

            try postings.?.distribute(&doc_ids);

            // Write postings
            vocab_offsets[i].postings = @truncate(self.writer.logicalPos() - postings_start);

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

        const postings_end = self.writer.logicalPos();

        // Write out the vocab
        const vocab_start = self.writer.logicalPos();

        for (dictionary.store, 0..) |postings, i| {
            if (postings == null) continue;

            // Write postings
            vocab_offsets[i].term = @truncate(self.writer.logicalPos() - vocab_start);
            try self.writeStr(postings.?.term);
        }

        const vocab_end = self.writer.logicalPos();

        // Document ID strings
        const docs_offsets = try allocator.alloc(config.FileOffsetType, docs.items.len);

        const docs_start = self.writer.logicalPos();

        var max_doc_length: u32 = 0;
        for (docs.items, 0..) |d, i| {
            if (d.len > max_doc_length) max_doc_length = d.len;
            docs_offsets[i] = @truncate(self.writer.logicalPos() - docs_start);
            try self.writeStr(d.name);
            try self.writeStr(d.title);
        }

        const docs_end = self.writer.logicalPos();

        // Snippets
        var snippets_offset: u64 = 0;
        if (self.snippets) {
            snippets_offset = self.writer.logicalPos();

            while (self.writer.logicalPos() % @alignOf(u64) != 0) try self.writer.interface.writeByte(0);
            try self.writer.interface.writeInt(u64, self.snippet_indices.items.len, native_endian);
            // TODO this should be a u64 array
            for (self.snippet_indices.items) |s|
                try self.writer.interface.writeInt(config.FileOffsetType, s, native_endian);
        }

        // Vocab
        while (self.writer.logicalPos() % @alignOf(u64) != 0) try self.writer.interface.writeByte(0);
        const vocab_offset = self.writer.logicalPos();
        try self.writer.interface.writeInt(u64, dictionary.cap, native_endian);
        try self.writer.interface.writeSliceEndian(index.VocabTuple, vocab_offsets, native_endian);

        // Document IDs array
        while (self.writer.logicalPos() % @alignOf(u64) != 0) try self.writer.interface.writeByte(0);
        const docs_offset = self.writer.logicalPos();
        try self.writer.interface.writeInt(u64, docs.items.len, native_endian);
        try self.writer.interface.writeSliceEndian(config.FileOffsetType, docs_offsets, native_endian);

        // Header
        while (self.writer.logicalPos() % @alignOf(index.Header) != 0) try self.writer.interface.writeByte(0);
        try self.writer.interface.writeStruct(index.Header{
            // precomputed values
            .max_doc_length = max_doc_length,

            // "sub-files"
            .snippets_store = .{ snippets_start, snippets_end },
            .blocks_store = .{ blocks_start, blocks_end },
            .postings_store = .{ postings_start, postings_end },
            .vocab_store = .{ vocab_start, vocab_end },
            .docs_store = .{ docs_start, docs_end },

            // structures
            .snippets = snippets_offset,
            .vocab = vocab_offset,
            .docs = docs_offset,

            // config
            .stemmer = stemmer,
            .version = index.version,
        }, native_endian);

        try self.writer.flush();

        return self.writer.logicalPos();
    }
};
