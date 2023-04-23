//	INDEX.ZIG
//	---------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const hash = @import("dictionary.zig").hash;
const Ranker = @import("ranking_fn.zig").Ranker;
const snippets = @import("snippets.zig");
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
    doc_lengths: []u32,
    max_length: u32,
    average_length: f64,
    docs_count: u32,
    docs_offset: u32,
    hash_offset: u32,
    snippets_offset: u32,

    pub fn init(allocator: std.mem.Allocator, index: []const u8) !Self {
        const docs_count = read32(index, index.len - 16);
        const docs_offset = read32(index, index.len - 12);
        const hash_offset = read32(index, index.len - 8);
        const snippets_offset = read32(index, index.len - 4);

        var doc_lengths = try allocator.alloc(u32, docs_count);
        var max_length: u32 = 0;
        var average_length: f64 = 0;

        var i: u32 = 0;
        while (i < docs_count) : (i += 1) {
            const offset = read32(index, docs_offset + i * @sizeOf(u32));
            doc_lengths[i] = read32(index, offset);
            if (doc_lengths[i] > max_length)
                max_length = doc_lengths[i];
            average_length += @intToFloat(f64, doc_lengths[i]);
        }
        average_length /= @intToFloat(f64, docs_count);

        return .{
            .index = index,
            .doc_lengths = doc_lengths,
            .max_length = max_length,
            .average_length = average_length,
            .hash_offset = hash_offset,
            .docs_offset = docs_offset,
            .snippets_offset = snippets_offset,
            .docs_count = docs_count,
        };
    }

    // [   u32   ][   u16   ][ []u8 ]
    // [ doclen  ][ strlen  ][ str  ]
    pub fn name(self: *const Self, doc_id: u32) []const u8 {
        const stride = doc_id * @sizeOf(u32);
        const name_offset = read32(self.index, self.docs_offset + stride) + @sizeOf(u32);
        const name_length = read16(self.index, name_offset);
        const name_start = name_offset + @sizeOf(u16);
        return self.index[name_start .. name_start + name_length];
    }

    pub fn snippet(self: *const Self, doc_id: u32) [2]u32 {
        const stride = doc_id * @sizeOf(u32);
        const start = read32(self.index, self.snippets_offset + stride);
        const end = read32(self.index, self.snippets_offset + stride + @sizeOf(u32));
        return [2]u32{ start, end };
    }

    fn postings_chunk(self: *const Self, offset: u32, ranker: *Ranker, results: []Result) void {
        const ids_len = read32(self.index, offset);
        const score = self.index[offset + @sizeOf(u32)];
        const ids = offset + @sizeOf(u32) + @sizeOf(u8);

        var i: u32 = 0;
        var last_id: u32 = 0;
        while (i < ids_len) {
            var doc_id: u32 = 0;
            i += vbyte.read(self.index[ids + i ..], &doc_id);
            doc_id += last_id;
            const doc_len = self.doc_lengths[doc_id];
            results[doc_id].score += ranker.compScore(@intToFloat(f64, score), @intToFloat(f64, doc_len));
            last_id = doc_id;
        }
    }

    fn postings(self: *const Self, offset: u32, ranker: *Ranker, results: []Result) void {
        var df_t = read32(self.index, offset);
        var chunk_offset = offset + @sizeOf(u32);
        var chunk_len = read32(self.index, chunk_offset);
        var chunk_score: u8 = 255;

        ranker.compIdf(@intToFloat(f64, df_t));

        while (chunk_len != 0) {
            chunk_score = self.index[chunk_offset + @sizeOf(u32)];
            self.postings_chunk(chunk_offset, ranker, results);
            if (chunk_score == 1)
                break;
            chunk_offset += @sizeOf(u32) + @sizeOf(u8) + chunk_len;
            chunk_len = read32(self.index, chunk_offset);
        }
    }

    pub fn find(self: *const Self, key: []const u8, ranker: *Ranker, results: []Result) void {
        const cap = read32(self.index, self.hash_offset);
        const table = self.hash_offset + @sizeOf(u32);

        var i = hash(key, cap);
        while (true) {
            const postings_offset = table + i * @sizeOf(u64);

            const term_store = read32(self.index, postings_offset);
            if (term_store == 0)
                return;
            const term_length = read16(self.index, term_store);
            const term_start = term_store + @sizeOf(u16);
            const term = self.index[term_start .. term_start + term_length];
            if (std.mem.eql(u8, term, key))
                return self.postings(read32(self.index, postings_offset + @sizeOf(u32)), ranker, results);

            i = i + 1 & (cap - 1);
        }
    }
};
