//	INDEX_STRUCTURE.ZIG
//	-------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const hash = @import("hash_table.zig").hash;
const Ranker = @import("ranking_fn.zig").Ranker;

pub const Result = struct {
    doc_id: u32,
    score: f64,
};

pub fn read32(index: []const u8, offset: usize) u32 {
    return std.mem.bytesToValue(u32, index[offset .. offset + @sizeOf(u32)][0..4]);
}

pub fn name(index: []const u8, offset: u32, doc_id: u32) []const u8 {
    const docs_start = offset + @sizeOf(u32);

    const stride = doc_id * @sizeOf(u32);
    const name_offset = read32(index, docs_start + stride) + @sizeOf(u32);
    const name_length = read32(index, name_offset);
    const name_start = name_offset + @sizeOf(u32);
    return index[name_start .. name_start + name_length];
}

fn doc_length(index: []const u8, offset: u32, doc_id: u32) u32 {
    const docs_start = offset + @sizeOf(u32);

    const stride = doc_id * @sizeOf(u32);
    const length_offset = read32(index, docs_start + stride);
    return read32(index, length_offset);
}

fn postings(index: []const u8, offset: u32, docs_offset: u32, ranker: *Ranker, results: []Result) void {
    const ids_offset = read32(index, offset);
    const ids_len = read32(index, ids_offset);

    const scores_offset = read32(index, offset + @sizeOf(u32));
    const scores_len = read32(index, scores_offset);
    const scores = scores_offset + @sizeOf(u32);

    ranker.compIdf(@intToFloat(f64, scores_len));

    var i: u32 = 0;
    while (i < ids_len) : (i += 1) {
        const stride = @sizeOf(u32) + i * @sizeOf(u32);
        const doc_id = read32(index, ids_offset + stride);
        const doc_len = doc_length(index, docs_offset, doc_id);
        results[doc_id].score += ranker.compScore(@intToFloat(f64, index[scores + i]), @intToFloat(f64, doc_len));
    }
}

pub fn find(index: []const u8, offset: u32, docs_offset: u32, key: []const u8, ranker: *Ranker, results: []Result) void {
    const cap = read32(index, offset);
    const table = offset + @sizeOf(u32);

    var i = hash(key, cap);
    while (true) {
        const posting_offset = table + i * @sizeOf(u32);

        const posting = read32(index, posting_offset);
        if (posting == 0)
            return;
        const term_store = read32(index, posting);
        const term_length = read32(index, term_store);
        const term_start = term_store + @sizeOf(u32);
        const term = index[term_start .. term_start + term_length];
        if (std.mem.eql(u8, term, key))
            return postings(index, posting + @sizeOf(u32), docs_offset, ranker, results);

        i = i + 1 & (cap - 1);
    }
}
