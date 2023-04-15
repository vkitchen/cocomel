//	INDEX.ZIG
//	---------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const hash = @import("dictionary.zig").hash;
const Ranker = @import("ranking_fn.zig").Ranker;

pub const Result = struct {
    doc_id: u32,
    score: f64,
};

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

    pub fn name(this: *const Self, doc_id: u32) []const u8 {
        const docs_start = this.docs_offset + @sizeOf(u32);

        const stride = doc_id * @sizeOf(u32);
        const name_offset = read32(this.index, docs_start + stride) + @sizeOf(u32);
        const name_length = read32(this.index, name_offset);
        const name_start = name_offset + @sizeOf(u32);
        return this.index[name_start .. name_start + name_length];
    }

    pub fn snippet(this: *const Self, doc_id: u32, buf: []u8, snippets_file: std.fs.File) ![]const u8 {
        const snippets_start = this.snippets_offset + @sizeOf(u32);

        const stride = doc_id * @sizeOf(u32);
        const start = read32(this.index, snippets_start + stride);
        const end = read32(this.index, snippets_start + stride + @sizeOf(u32));
        const read_size = std.math.min(buf.len, end - start);
        try snippets_file.seekTo(start);
        const bytes_read = try snippets_file.readAll(buf[0..read_size]);

        return buf[0..bytes_read];
    }

    fn doc_length(this: *const Self, offset: u32, doc_id: u32) u32 {
        const docs_start = offset + @sizeOf(u32);

        const stride = doc_id * @sizeOf(u32);
        const length_offset = read32(this.index, docs_start + stride);
        return read32(this.index, length_offset);
    }

    fn postings(this: *const Self, offset: u32, ranker: *Ranker, results: []Result) void {
        const ids_offset = read32(this.index, offset);
        const ids_len = read32(this.index, ids_offset);

        const scores_offset = read32(this.index, offset + @sizeOf(u32));
        const scores_len = read32(this.index, scores_offset);
        const scores = scores_offset + @sizeOf(u32);

        ranker.compIdf(@intToFloat(f64, scores_len));

        var i: u32 = 0;
        while (i < ids_len) : (i += 1) {
            const stride = @sizeOf(u32) + i * @sizeOf(u32);
            const doc_id = read32(this.index, ids_offset + stride);
            const doc_len = this.doc_length(this.docs_offset, doc_id);
            results[doc_id].score += ranker.compScore(@intToFloat(f64, this.index[scores + i]), @intToFloat(f64, doc_len));
        }
    }

    pub fn find(this: *const Self, key: []const u8, ranker: *Ranker, results: []Result) void {
        const cap = read32(this.index, this.hash_offset);
        const table = this.hash_offset + @sizeOf(u32);

        var i = hash(key, cap);
        while (true) {
            const posting_offset = table + i * @sizeOf(u32);

            const posting = read32(this.index, posting_offset);
            if (posting == 0)
                return;
            const term_store = read32(this.index, posting);
            const term_length = read32(this.index, term_store);
            const term_start = term_store + @sizeOf(u32);
            const term = this.index[term_start .. term_start + term_length];
            if (std.mem.eql(u8, term, key))
                return this.postings(posting + @sizeOf(u32), ranker, results);

            i = i + 1 & (cap - 1);
        }
    }
};
