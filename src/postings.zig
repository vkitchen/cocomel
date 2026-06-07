// POSTINGS.ZIG
// ------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const ArrayChain = @import("array_chain.zig").ArrayChain;
const Doc = @import("doc.zig");
const Ranker = @import("ranking_fn_bm25.zig").Ranker;
const Quantiser = @import("quantiser.zig").Quantiser;
const vbyte = @import("compress_int_vbyte.zig");

pub const Postings = struct {
    const Self = @This();

    term: []u8,
    df_t: u32 = 0,
    id: u32,
    last_id: u32 = 0,
    freq: u8 = 1,
    ids: ArrayChain = .{},
    tfs: ArrayChain = .{},

    pub fn init(term: []u8, id: u32) Self {
        return .{ .term = term, .id = id };
    }

    pub fn flush(self: *Self, allocator: std.mem.Allocator) !void {
        try self.ids.ensureUnusedCapacity(allocator, 5);
        const chunk = self.ids.last.?;
        const last = chunk.items.len;
        chunk.items.len += 5;
        chunk.items.len -= 5 - vbyte.store(chunk.items[last..], self.id - self.last_id);
        try self.tfs.append(allocator, self.freq);
        self.last_id = self.id;
        self.df_t += 1;
        self.freq = 1;
    }

    pub fn score(self: *Self, docs: *std.ArrayList(Doc), ranker: *Ranker) [2]f64 {
        var min_score: f64 = std.math.floatMax(f64);
        var max_score: f64 = 0;

        ranker.compIdf(@floatFromInt(self.df_t + 1));

        var ids_chunk = self.ids.first;
        var tfs_chunk = self.tfs.first;
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
            if (doc_score > max_score) max_score = doc_score;

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
        const doc_len = docs.items[self.id].len;
        const doc_score = ranker.compScore(@floatFromInt(self.freq), @floatFromInt(doc_len));
        if (doc_score < min_score) min_score = doc_score;
        if (doc_score > max_score) max_score = doc_score;

        return .{ min_score, max_score };
    }

    pub fn quantise(self: *Self, allocator: std.mem.Allocator, docs: *std.ArrayList(Doc), ranker: *Ranker, quantiser: Quantiser, doc_ids: *[256]std.ArrayList(u8)) !void {
        var last_ids = [_]u32{0} ** 256;

        ranker.compIdf(@floatFromInt(self.df_t + 1));

        var ids_chunk = self.ids.first;
        var tfs_chunk = self.tfs.first;
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
            doc_ids[rsv].items.len += 5;
            doc_ids[rsv].items.len -= 5 - vbyte.store(doc_ids[rsv].items[last..], doc_id - last_ids[rsv]);
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
        const doc_len = docs.items[self.id].len;
        const doc_score = ranker.compScore(@floatFromInt(self.freq), @floatFromInt(doc_len));
        const rsv = quantiser.quantise(doc_score);
        try doc_ids[rsv].ensureUnusedCapacity(allocator, 5);
        const last = doc_ids[rsv].items.len;
        doc_ids[rsv].items.len += 5;
        doc_ids[rsv].items.len -= 5 - vbyte.store(doc_ids[rsv].items[last..], self.id - last_ids[rsv]);
    }
};
