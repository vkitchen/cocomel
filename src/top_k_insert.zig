// TOP_K_INSERT.ZIG
// ----------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const Result = @import("index.zig").Result;

fn cmpResults(context: void, a: Result, b: Result) bool {
    return std.sort.desc(u16)(context, a.score, b.score);
}

pub var store: [1000]Result = undefined;

pub const TopKInsert = struct {
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
        const worst_score: u16 = store[self.len - 1].score;
        // Can't make top-k
        if (self.len == self.cap and key.score <= worst_score) return;
        // First try to promote
        for (0..self.len) |i| {
            if (store[i].doc_id == key.doc_id) {
                store[i].score = key.score;

                // Resort top-k
                std.sort.pdq(Result, store[0..self.len], {}, cmpResults);
                return;
            }
        }
        if (self.len < self.cap) {
            // Can append?
            store[self.len] = key;
            self.len += 1;
        } else {
            // Replace worst
            store[self.len - 1] = key;
        }
        // Resort top-k
        std.sort.pdq(Result, store[0..self.len], {}, cmpResults);
    }

    pub fn results(self: *Self) []Result {
        return store[0..self.len];
    }

    pub fn sorted(self: *Self) []Result {
        return self.results();
    }
};
