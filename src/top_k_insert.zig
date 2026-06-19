// TOP_K_INSERT.ZIG
// ----------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");

const Result = @import("index.zig").Result;

pub var store: [config.max_top_k]Result = undefined;

fn lt(a: Result, b: Result) bool {
    return a.score < b.score or (a.score == b.score and a.docid > b.docid);
}

pub const TopKInsert = struct {
    const Self = @This();

    cap: u32 = config.max_top_k,
    len: u32 = 0,

    pub fn clearRetainingCapacity(self: *Self) void {
        self.len = 0;
    }

    pub fn saturate(self: *Self, key: Result) void {
        if (self.len == self.cap) return;
        store[self.len] = key;
        self.len += 1;
    }

    pub fn insert(self: *Self, key: Result, _: u32) void {
        const worst: Result = store[self.len - 1];
        // Can't make top-k
        if (self.len == self.cap and lt(key, worst)) return;
        // Find insert spot
        var i: usize = 0;
        while (i < self.len and lt(key, store[i]))
            i += 1;

        // Swap our new doc in
        var bumped = store[i];
        store[i] = key;
        // We upgraded this doc and are now done
        if (key.docid == bumped.docid)
            return;
        i += 1;
        // Shuffle down remainder
        while (i < self.len) : (i += 1) {
            const tmp = store[i];
            store[i] = bumped;
            bumped = tmp;
            // We upgraded this doc and are now done
            if (key.docid == bumped.docid)
                return;
        }
        // Can append bumped doc?
        if (self.len < self.cap) {
            store[self.len] = bumped;
            self.len += 1;
        }
    }

    pub fn results(self: *Self) []Result {
        return store[0..self.len];
    }

    // Already sorted
    pub fn sorted(self: *Self) []Result {
        return store[0..self.len];
    }
};

// TODO unit tests. This is mildly complex logic
