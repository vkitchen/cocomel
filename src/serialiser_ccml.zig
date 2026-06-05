// SERIALISER_CCML.ZIG
// -------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const index = @import("index.zig");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("doc.zig");
const Posting = @import("dictionary.zig").Posting;
const Ranker = @import("ranking_fn_bm25.zig").Ranker;
const Quantiser = @import("quantiser.zig").Quantiser;
const vbyte = @import("compress_int_vbyte.zig");
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

    pub fn write(self: *Self, allocator: std.mem.Allocator, docs: *std.ArrayList(Doc), dictionary: *Dictionary) !u64 {
        // Flush snippets
        try self.newDocId(allocator);

        // Snippets
        const snippets_offset = if (self.snippets) self.writer.logicalPos() else 0;
        for (self.snippet_indices.items) |s|
            try self.writer.interface.writeInt(u32, s, native_endian);

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
            const posting = post.?;

            posting.df_t += 1;

            ranker.compIdf(@floatFromInt(posting.df_t));

            var ids_chunk = posting.ids.first;
            var tfs_chunk = posting.tfs.first;
            var ids_i: u32 = 0;
            var tfs_i: u32 = 0;
            var last_id: u32 = 0;
            while (ids_chunk != null) {
                // Decode vbyte
                var doc_id: u32 = 0;
                ids_i += vbyte.read(ids_chunk.?.items[ids_i..], &doc_id);
                doc_id += last_id;
                const doc_len = docs.items[doc_id].len;
                const doc_score = ranker.compScore(@floatFromInt(tfs_chunk.?.items[tfs_i]), @floatFromInt(doc_len));
                tfs_i += 1;
                if (doc_score < min_score) min_score = doc_score;
                if (doc_score > min_score) max_score = doc_score;

                if (ids_i >= ids_chunk.?.items.len) {
                    ids_chunk = ids_chunk.?.next;
                    ids_i = 0;
                }
                if (tfs_i >= tfs_chunk.?.items.len) {
                    tfs_chunk = tfs_chunk.?.next;
                    tfs_i = 0;
                }
                last_id = doc_id;
            }

            // Score last
            const doc_len = docs.items[posting.id].len;
            const doc_score = ranker.compScore(@floatFromInt(posting.freq), @floatFromInt(doc_len));
            if (doc_score < min_score) min_score = doc_score;
            if (doc_score > min_score) max_score = doc_score;
        }

        const dictionary_offsets = try allocator.alloc(u32, dictionary.cap);
        @memset(dictionary_offsets, 0);

        // Quantise
        var doc_ids = [_]std.ArrayList(u8){.empty} ** 256;
        var last_ids = [_]u32{0} ** 256;

        var quantiser = Quantiser.init(min_score, max_score);

        var vbyte_buf: [5]u8 = undefined;
        for (dictionary.store, 0..) |post, hi| {
            if (post == null) continue;
            const posting = post.?;

            for (&doc_ids) |*d| d.clearRetainingCapacity();
            @memset(&last_ids, 0);

            ranker.compIdf(@floatFromInt(posting.df_t));

            // Special case unique terms
            if (posting.df_t == 1) {
                const doc_len = docs.items[posting.id].len;
                const doc_score = ranker.compScore(@floatFromInt(posting.freq), @floatFromInt(doc_len));
                const rsv = quantiser.quantise(doc_score);
                const len = vbyte.store(&vbyte_buf, posting.id);

                // Write posting
                const term_offset = self.writer.logicalPos();
                try self.writeStr(posting.term);

                // Write chunks
                try self.writer.interface.writeInt(u32, len, native_endian);
                try self.writer.interface.writeInt(u8, rsv, native_endian);
                try self.writer.interface.writeAll(vbyte_buf[0..len]);
                // Null terminate
                try self.writer.interface.writeInt(u32, 0, native_endian);

                dictionary_offsets[hi] = @truncate(term_offset);

                continue;
            }

            var ids_chunk = posting.ids.first;
            var tfs_chunk = posting.tfs.first;
            var ids_i: u32 = 0;
            var tfs_i: u32 = 0;
            var last_id: u32 = 0;
            while (ids_chunk != null) {
                // decode vbyte
                var doc_id: u32 = 0;
                ids_i += vbyte.read(ids_chunk.?.items[ids_i..], &doc_id);
                doc_id += last_id;
                const doc_len = docs.items[doc_id].len;
                const doc_score = ranker.compScore(@floatFromInt(tfs_chunk.?.items[tfs_i]), @floatFromInt(doc_len));
                const rsv = quantiser.quantise(doc_score);
                tfs_i += 1;

                // Store quantised value
                try doc_ids[rsv].ensureUnusedCapacity(allocator, 5);
                const last = doc_ids[rsv].items.len;
                doc_ids[rsv].items.len += vbyte.spaceRequired(doc_id - last_ids[rsv]);
                _ = vbyte.store(doc_ids[rsv].items[last..], doc_id - last_ids[rsv]);
                last_ids[rsv] = doc_id;

                if (ids_i >= ids_chunk.?.items.len) {
                    ids_chunk = ids_chunk.?.next;
                    ids_i = 0;
                }
                if (tfs_i >= tfs_chunk.?.items.len) {
                    tfs_chunk = tfs_chunk.?.next;
                    tfs_i = 0;
                }
                last_id = doc_id;
            }

            // Quantise last
            const doc_len = docs.items[posting.id].len;
            const doc_score = ranker.compScore(@floatFromInt(posting.freq), @floatFromInt(doc_len));
            const rsv = quantiser.quantise(doc_score);
            try doc_ids[rsv].ensureUnusedCapacity(allocator, 5);
            const last = doc_ids[rsv].items.len;
            doc_ids[rsv].items.len += vbyte.spaceRequired(posting.id - last_ids[rsv]);
            _ = vbyte.store(doc_ids[rsv].items[last..], posting.id - last_ids[rsv]);

            // Write postings
            const term_offset = self.writer.logicalPos();
            try self.writeStr(posting.term);

            // Write chunks
            var i: u8 = 255;
            while (i > 0) : (i -= 1) {
                if (doc_ids[i].items.len == 0)
                    continue;
                try self.writer.interface.writeInt(u32, @truncate(doc_ids[i].items.len), native_endian);
                try self.writer.interface.writeInt(u8, i, native_endian);
                try self.writer.interface.writeAll(doc_ids[i].items);
            }
            // Null terminate
            try self.writer.interface.writeInt(u32, 0, native_endian);

            dictionary_offsets[hi] = @truncate(term_offset);
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
        const docs_offset = self.writer.logicalPos();
        for (docs.items) |d|
            try self.writer.interface.writeInt(u32, @truncate(@intFromPtr(d.name.ptr)), native_endian);

        // Dictionary
        const dictionary_offset = self.writer.logicalPos();
        try self.writer.interface.writeInt(u32, dictionary.cap, native_endian);
        try self.writer.interface.writeSliceEndian(u32, dictionary_offsets, native_endian);

        std.debug.print("Terms count {d}\n", .{dictionary.len});

        // Header
        try self.writer.interface.writeStruct(index.Header{
            .docs_count = @truncate(docs.items.len),
            .docs_offset = @truncate(docs_offset),
            .dictionary_offset = @truncate(dictionary_offset),
            .snippets_offset = @truncate(snippets_offset),
            .max_doc_length = max_doc_length,
            .version = config.index_version,
        }, native_endian);

        try self.writer.flush();

        return self.writer.logicalPos();
    }
};
