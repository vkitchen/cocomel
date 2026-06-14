// TOP_K_FIND.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const Result = @import("index.zig").Result;

fn cmpResults(context: void, a: Result, b: Result) bool {
    return std.sort.desc(u16)(context, a.score, b.score);
}

pub var store: [1000]Result = undefined;

pub const TopKFind = struct {
    const Self = @This();

    cap: u32 = 1000,
    len: u32 = 0,

    pub fn clearRetainingCapacity(self: *Self) void {
        self.len = 0;
    }

    pub fn saturate(self: *Self, key: Result) void {
        if (self.len == self.cap) return;
        store[self.len] = key;
        self.len += 1;
    }

    pub fn insert(self: *Self, key: Result) void {
        var worst_pos: usize = 0;
        var worst_score: u16 = std.math.maxInt(u16);
        // First try to promote
        for (0..self.len) |i| {
            if (store[i].doc_id == key.doc_id) {
                store[i].score = key.score;
                return;
            }
            // Find worst
            if (store[i].score < worst_score) {
                worst_score = store[i].score;
                worst_pos = i;
            }
        }
        // Can append?
        if (self.len < self.cap) {
            store[self.len] = key;
            self.len += 1;
            return;
        }
        // Top-k is full. Replace the worst scoring
        if (key.score > worst_score)
            store[worst_pos] = key;
    }

    pub fn results(self: *Self) []Result {
        return store[0..self.len];
    }

    pub fn sorted(self: *Self) []Result {
        std.sort.pdq(Result, store[0..self.len], {}, cmpResults);
        return store[0..self.len];
    }
};
