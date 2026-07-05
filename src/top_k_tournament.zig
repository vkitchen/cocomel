// TOP_K_TOURNAMENT.ZIG
// --------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("index.zig").Result;
const tournament = @import("tournament.zig");

var cache: [config.max_top_k]*config.AccumulatorType = undefined;

fn cmpResults(_: void, a: Result, b: Result) bool {
    // Score descending
    if (a.score != b.score)
        return a.score > b.score;

    // ID ascending
    return a.docid < b.docid;
}

pub const TopKTournament = struct {
    const Self = @This();

    accumulators: [*]config.AccumulatorType,
    cap: u32 = config.max_top_k,
    len: u32 = 0,
    saturated: bool = false,
    top_k_lower_bound: config.AccumulatorType = undefined, // cache the lower bound for performance

    pub fn init(accumulators: [*]config.AccumulatorType) Self {
        return .{ .accumulators = accumulators };
    }

    pub fn clearRetainingCapacity(self: *Self) void {
        self.len = 0;
        self.saturated = false;
    }

    pub fn insert(self: *Self, docid: u32, is: config.AccumulatorType, was: config.AccumulatorType) void {
        // Tree requires more elements
        if (!self.saturated) {
            // First time this doc has been accumulated (new tree entry)
            if (was == 0) {
                cache[self.len] = &self.accumulators[docid];
                self.len += 1;

                if (self.len == self.cap) {
                    tournament.len = 0;
                    for (0..self.len) |i|
                        tournament.append(@intCast(cache[i] - self.accumulators), cache[i].*);
                    tournament.make();
                    self.top_k_lower_bound = tournament.tree[0].score;
                    self.saturated = true;
                }
            }

            return;
        }

        // Can't enter tree
        if (is < self.top_k_lower_bound or (is == self.top_k_lower_bound and docid > tournament.bottomDoc()))
            return;

        // Previously didn't enter tree. Or is bottom of tree. Insert
        if (was < self.top_k_lower_bound or (was == self.top_k_lower_bound and docid >= tournament.bottomDoc())) {
            tournament.replace(docid, is);
            self.top_k_lower_bound = tournament.tree[0].score;
            return;
        }

        // Was in the tree. Promote (can't affect root)
        const where = tournament.find(docid);
        tournament.promote(where, is);
    }

    pub fn results(self: *Self, buf: []Result) []Result {
        for (0..self.len) |i| {
            buf[i] = .{ .docid = tournament.docids[i], .score = tournament.tree[i + tournament.cap].score };
        }
        std.sort.pdq(Result, buf[0..self.len], {}, cmpResults);
        return buf[0..self.len];
    }
};
