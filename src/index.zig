//	INDEX.ZIG
//	---------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const hash = @import("dictionary.zig").hash;
const Ranker = @import("ranking_fn.zig").Ranker;
const vbyte = @import("compress_int_vbyte.zig");

pub const Result = struct {
    doc_id: u32,
    score: f64,
};

fn read16(str: []const u8, offset: usize) u16 {
    return std.mem.bytesToValue(u16, str[offset .. offset + @sizeOf(u16)][0..2]);
}

fn read32(str: []const u8, offset: usize) u32 {
    return std.mem.bytesToValue(u32, str[offset .. offset + @sizeOf(u32)][0..4]);
}

pub const Index = struct {
    const Self = @This();

    index: []const u8,
    hash_offset: u32,
    docs_offset: u32,
    snippets_offset: u32,
    docs_count: u32,
    average_length: f64,

    pub fn init(index: []const u8) Self {
        const hash_offset = read32(index, index.len - 4);
        const docs_offset = read32(index, index.len - 8);
        const snippets_offset = read32(index, index.len - 12);

        const docs_count = read32(index, docs_offset);

        var average_length: f64 = 0;
        const docs_start = docs_offset + @sizeOf(u32);
        var i: u32 = 0;
        while (i < docs_count) : (i += 1) {
            const name_offset = read32(index, docs_start + i * @sizeOf(u32));
            average_length += @intToFloat(f64, read32(index, name_offset));
        }
        average_length /= @intToFloat(f64, docs_count);

        return .{
            .index = index,
            .hash_offset = hash_offset,
            .docs_offset = docs_offset,
            .snippets_offset = snippets_offset,
            .docs_count = docs_count,
            .average_length = average_length,
        };
    }

    pub fn name(self: *const Self, doc_id: u32) []const u8 {
        const docs_start = self.docs_offset + @sizeOf(u32);

        const stride = doc_id * @sizeOf(u32);
        const name_offset = read32(self.index, docs_start + stride) + @sizeOf(u32);
        const name_length = read16(self.index, name_offset);
        const name_start = name_offset + @sizeOf(u16);
        return self.index[name_start .. name_start + name_length];
    }

    pub fn snippet(self: *const Self, doc_id: u32, buf: []u8, snippets_file: std.fs.File) ![]const u8 {
        const snippets_start = self.snippets_offset + @sizeOf(u32);

        const stride = doc_id * @sizeOf(u32);
        const start = read32(self.index, snippets_start + stride);
        const end = read32(self.index, snippets_start + stride + @sizeOf(u32));
        const read_size = std.math.min(buf.len, end - start);
        try snippets_file.seekTo(start);
        const bytes_read = try snippets_file.readAll(buf[0..read_size]);

        return buf[0..bytes_read];
    }

    fn doc_length(self: *const Self, offset: u32, doc_id: u32) u32 {
        const docs_start = offset + @sizeOf(u32);

        const stride = doc_id * @sizeOf(u32);
        const length_offset = read32(self.index, docs_start + stride);
        return read32(self.index, length_offset);
    }

    fn postings(self: *const Self, offset: u32, ranker: *Ranker, results: []Result) void {
        const ids_offset = read32(self.index, offset);
        const ids_len = read32(self.index, ids_offset);
        const ids = ids_offset + @sizeOf(u32);

        const scores_offset = read32(self.index, offset + @sizeOf(u32));
        const scores_len = read32(self.index, scores_offset);
        const scores = scores_offset + @sizeOf(u32);

        ranker.compIdf(@intToFloat(f64, scores_len));

        var i: u32 = 0;
        var id_i: u32 = 0;
        var last_id: u32 = 0;
        while (i < scores_len and id_i < ids_len) : (i += 1) {
            var doc_id: u32 = 0;
            id_i += vbyte.read(self.index[ids + id_i ..], &doc_id);
            doc_id += last_id;
            const doc_len = self.doc_length(self.docs_offset, doc_id);
            results[doc_id].score += ranker.compScore(@intToFloat(f64, self.index[scores + i]), @intToFloat(f64, doc_len));
            last_id = doc_id;
        }
    }

    pub fn find(self: *const Self, key: []const u8, ranker: *Ranker, results: []Result) void {
        const cap = read32(self.index, self.hash_offset);
        const table = self.hash_offset + @sizeOf(u32);

        var i = hash(key, cap);
        while (true) {
            const posting_offset = table + i * @sizeOf(u32);

            const posting = read32(self.index, posting_offset);
            if (posting == 0)
                return;
            const term_store = read32(self.index, posting);
            const term_length = read16(self.index, term_store);
            const term_start = term_store + @sizeOf(u16);
            const term = self.index[term_start .. term_start + term_length];
            if (std.mem.eql(u8, term, key))
                return self.postings(posting + @sizeOf(u32), ranker, results);

            i = i + 1 & (cap - 1);
        }
    }
};
