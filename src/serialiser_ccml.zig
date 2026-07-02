// SERIALISER_CCML.ZIG
// -------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Wyhash = std.hash.Wyhash;

const config = @import("config.zig");
const index = @import("index.zig");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("doc.zig");
const compress = @import("compress_int.zig");
const Stemmer = @import("stem.zig").Stemmer;
const Postings = @import("postings.zig").Postings;
const Ranker = @import("ranking_fn_bm25.zig").Ranker;
const Quantiser = @import("quantiser.zig").Quantiser;
const vbyte = @import("compress_int_vbyte.zig");
const native_endian = @import("builtin").target.cpu.arch.endian();

const c = @import("c");

const file_format = std.fmt.comptimePrint("cocomel v{d}\n", .{index.version});

var writer_buf: [config.io_buffer_size]u8 = undefined;
var scratch_buf: [config.io_buffer_size]u8 = undefined;

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
        try self.snippet_indices.append(allocator, @truncate(self.writer.logicalPos() - file_format.len));
    }

    fn writeStr(self: *Self, str: []u8) !void {
        try self.writer.interface.writeAll(str);
        try self.writer.interface.writeByte(0);
    }

    fn writePostings(self: *Self, io: std.Io, allocator: std.mem.Allocator, dictionary: *Dictionary(*Postings), vocab_offsets: []index.VocabTuple, compressor: compress.Compressor) ![4]u64 {
        var vbyte_buffer: [5]u8 = undefined;

        // Get statistics
        var best = [_]u32{0} ** (1 << config.quantise_bits);

        for (dictionary.store) |pair| {
            if (pair.key == null) continue;
            const postings = pair.val.?;

            postings.statistics(&best);
        }

        var longest_segment: u32 = 0;
        for (0..(1 << config.quantise_bits)) |i| {
            if (best[i] > longest_segment)
                longest_segment = best[i];
        }

        // Buffers
        var doc_ids = [_]std.ArrayList(u32){.empty} ** (1 << config.quantise_bits);
        for (&doc_ids, 0..) |*d, i| try d.resize(allocator, best[i]); // reserve so arena doesn't get trampled

        const blocks_buffer = try allocator.alloc(u128, longest_segment / 4);
        const bytes_buffer = try allocator.alloc(u8, longest_segment * @sizeOf(u32));

        // Scratch
        var scratch_file = try std.Io.Dir.cwd().createFile(io, config.scratch_name, .{});
        var scratch_writer = scratch_file.writer(io, &scratch_buf);

        // Write out the segments themselves
        while (self.writer.logicalPos() % @alignOf(u128) != 0) try self.writer.interface.writeByte(0);
        const blocks_start = self.writer.logicalPos();

        for (dictionary.store, 0..) |pair, i| {
            if (pair.key == null) continue;
            const postings = pair.val.?;

            for (&doc_ids) |*d| d.clearRetainingCapacity();

            try postings.distribute(&doc_ids);

            vocab_offsets[i].term = scratch_writer.logicalPos();

            // Write term
            try scratch_writer.interface.writeAll(pair.key.?);
            try scratch_writer.interface.writeByte(0); // null terminate

            // Secondary hash for term
            const hash2 = Wyhash.hash(42, pair.key.?);
            vocab_offsets[i].hash = hash2;

            // Count the segments
            var num_segments: index.ImpactType = 0;
            for (doc_ids) |d| {
                if (d.items.len != 0)
                    num_segments += 1;
            }

            // Store segment count
            try scratch_writer.interface.writeInt(index.ImpactType, num_segments, native_endian);

            // Store segment headers
            var impact: index.ImpactType = (1 << config.quantise_bits) - 1;
            while (impact > 0) : (impact -= 1) {
                if (doc_ids[impact].items.len == 0)
                    continue;

                // Impact
                try scratch_writer.interface.writeInt(index.ImpactType, impact, native_endian);
                // No. docs
                const segment_len = vbyte.store(&vbyte_buffer, @truncate(doc_ids[impact].items.len));
                try scratch_writer.interface.writeAll(vbyte_buffer[0..segment_len]);
            }

            // Store the block offset
            const block_offset = (self.writer.logicalPos() - blocks_start) / 16; // block id

            const block_offset_len = vbyte.store(&vbyte_buffer, @truncate(block_offset)); // TODO this could be u64
            try scratch_writer.interface.writeAll(vbyte_buffer[0..block_offset_len]);

            // Write blocks and segment metadata
            impact = (1 << config.quantise_bits) - 1;
            while (impact > 0) : (impact -= 1) {
                if (doc_ids[impact].items.len == 0)
                    continue;

                // Blocks
                const written = compress.pack_stream(compressor, blocks_buffer, bytes_buffer, doc_ids[impact].items);
                try self.writer.interface.writeAll(std.mem.sliceAsBytes(blocks_buffer[0..written.blocks]));

                // Metadata
                try scratch_writer.interface.writeAll(bytes_buffer[0..written.bytes]);
            }
        }

        const blocks_end = self.writer.logicalPos();

        const postings_start = self.writer.logicalPos();

        // Include the scratch file into the index
        try scratch_writer.flush();

        // TODO can this be done without closing and reopening the file?
        scratch_file.close(io);
        scratch_file = try std.Io.Dir.cwd().openFile(io, config.scratch_name, .{});

        var scratch_reader = scratch_file.reader(io, &scratch_buf);
        _ = try scratch_reader.interface.streamRemaining(&self.writer.interface);

        scratch_file.close(io);
        try std.Io.Dir.cwd().deleteFile(io, config.scratch_name);

        const postings_end = self.writer.logicalPos();

        return .{ blocks_start, blocks_end, postings_start, postings_end };
    }

    // This goes over the index multiple times to avoid allocating excessive memory
    pub fn write(self: *Self, io: std.Io, allocator: std.mem.Allocator, docs: *std.ArrayList(Doc), dictionary: *Dictionary(*Postings), compressor: compress.Compressor, stemmer: Stemmer.Alg, quantise: bool) !u64 {
        // Flush snippets
        try self.newDocId(allocator);

        const snippets_start: u64 = file_format.len;
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

            for (dictionary.store) |pair| {
                if (pair.key == null) continue;
                const post = pair.val.?;

                const scores = post.score(docs, &ranker);

                if (scores[0] < min_score) min_score = scores[0];
                if (scores[1] > max_score) max_score = scores[1];
            }

            // Actually quantise now
            const quantiser = Quantiser.init(min_score, max_score);

            for (dictionary.store) |pair| {
                if (pair.key == null) continue;
                const post = pair.val.?;

                try post.quantise(docs, &ranker, quantiser);
            }
        }

        // Write postings
        const vocab_offsets = try allocator.alloc(index.VocabTuple, dictionary.cap);
        @memset(vocab_offsets, .{ .term = 0, .hash = 0 });

        const postings = try self.writePostings(io, allocator, dictionary, vocab_offsets, compressor);

        // Document ID strings
        const docs_offsets = try allocator.alloc(config.FileOffsetType, docs.items.len);

        const docs_start = self.writer.logicalPos();

        // TODO the indexer should probably know this already
        var has_titles: bool = false;
        for (docs.items) |d| {
            if (d.title.len > 0)
                has_titles = true;
        }

        var max_doc_length: u32 = 0;
        for (docs.items, 0..) |d, i| {
            if (d.len > max_doc_length) max_doc_length = d.len;
            docs_offsets[i] = @truncate(self.writer.logicalPos() - docs_start);
            try self.writeStr(d.name);
            if (has_titles)
                try self.writeStr(d.title);
        }

        const docs_end = self.writer.logicalPos();

        // Snippets
        var snippets_offset: u64 = 0;
        if (self.snippets) {
            while (self.writer.logicalPos() % @alignOf(u64) != 0) try self.writer.interface.writeByte(0);
            snippets_offset = self.writer.logicalPos();
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
            .blocks_store = .{ postings[0], postings[1] },
            .postings_store = .{ postings[2], postings[3] },
            .docs_store = .{ docs_start, docs_end },

            // structures
            .snippets = snippets_offset,
            .vocab = vocab_offset,
            .docs = docs_offset,

            // config
            .compressor = compressor,
            .stemmer = stemmer,
            .doc_fields = if (has_titles) 2 else 1,
            .version = index.version,
        }, native_endian);

        try self.writer.flush();

        return self.writer.logicalPos();
    }
};
