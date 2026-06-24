// POSTINGS.ZIG
// ------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const ArrayChain = @import("array_chain.zig").ArrayChain;
const Doc = @import("doc.zig");
const Ranker = @import("ranking_fn_bm25.zig").Ranker;
const Quantiser = @import("quantiser.zig").Quantiser;
const vbyte = @import("compress_int_vbyte.zig");

pub const Postings = struct {
    const Self = @This();

    df_t: u32 = 0,
    id: u32,
    last_id: u32 = 0,
    freq: config.TermFrequencyType = 1,
    ids: ArrayChain(u8) = .{},
    tfs: ArrayChain(config.TermFrequencyType) = .{},

    pub fn init(doc_id: u32) Self {
        return .{ .id = doc_id };
    }

    pub fn initCapacity(allocator: std.mem.Allocator, cap: usize) !Self {
        if (cap == 1) return .{ .id = 0 }; // Postings of length 1 don't have backing chains

        return .{
            .id = 0,
            .tfs = try ArrayChain(config.TermFrequencyType).initCapacity(allocator, cap),
        };
    }

    pub fn flush(self: *Self, allocator: std.mem.Allocator) !void {
        try self.ids.ensureUnusedCapacity(allocator, 5);
        const chunk = self.ids.last.?;
        const last = chunk.items.len;
        chunk.items.len += 5;
        chunk.items.len -= 5 - vbyte.store(chunk.items[last..], self.id - self.last_id);
        try self.tfs.append(allocator, self.freq);
        self.last_id = self.id;
        self.df_t += 1; // TODO move this to append and fix score function
    }

    pub fn append(self: *Self, allocator: std.mem.Allocator, doc_id: u32) !void {
        if (self.id == doc_id) {
            self.freq +|= 1;
            return;
        }

        try self.flush(allocator);
        self.id = doc_id;
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

    pub fn quantise(self: *Self, docs: *std.ArrayList(Doc), ranker: *Ranker, quantiser: Quantiser) !void {
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

            // quantise
            const doc_len = docs.items[doc_id].len;
            const doc_score = ranker.compScore(@floatFromInt(tfs_chunk.?.items[tfs_i]), @floatFromInt(doc_len));
            const rsv = quantiser.quantise(doc_score);
            tfs_chunk.?.items[tfs_i] = rsv;
            tfs_i += 1;

            // next chunk?
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
        self.freq = rsv;
    }

    pub fn distribute(self: *Self, doc_ids: *[1 << config.quantise_bits]std.ArrayList(u32)) !void {
        var last_ids = [_]u32{0} ** (1 << config.quantise_bits);

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
            const rsv = tfs_chunk.?.items[tfs_i];
            tfs_i += 1;

            // Store quantised value
            doc_ids[rsv].appendAssumeCapacity(doc_id - last_ids[rsv]);
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

        // Store last
        const rsv = self.freq;
        doc_ids[rsv].appendAssumeCapacity(self.id - last_ids[rsv]);
    }
};
