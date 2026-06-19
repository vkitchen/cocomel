// TOP_K_HEAP.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("index.zig").Result;
const heap = @import("heap.zig");

var store: [config.max_top_k]Result = undefined;

fn cmpResults(_: void, a: Result, b: Result) bool {
    // Score descending
    if (a.score != b.score)
        return a.score > b.score;

    // ID ascending
    return a.docid < b.docid;
}

pub const TopKHeap = struct {
    const Self = @This();

    cap: u32 = config.max_top_k,
    len: u32 = 0,
    saturated: bool = false,

    pub fn clearRetainingCapacity(self: *Self) void {
        self.len = 0;
        self.saturated = false;
    }

    pub fn saturate(self: *Self, key: Result) void {
        if (self.saturated) return;

        heap.docids[self.len] = key.docid;
        heap.scores[self.len] = key.score;
        self.len += 1;

        if (self.len == self.cap) {
            heap.make_heap();
            self.saturated = true;
        }
    }

    pub fn insert(self: *Self, key: Result, diff: u32) void {
        // Heap requires more elements
        if (!self.saturated) {
            // Was in the heap. Promote
            if (key.score - diff != 0) {
                const where = heap.find(key);
                heap.scores[where] = key.score;
                return;
            }
            // TODO handle unlikely case of querying 3rd term and heap isn't saturated

            heap.docids[self.len] = key.docid;
            heap.scores[self.len] = key.score;
            self.len += 1;

            if (self.len == self.cap) {
                heap.make_heap();
                self.saturated = true;
            }

            return;
        }

        // Can't enter heap
        if (key.score < heap.scores[0] or (key.score == heap.scores[0] and key.docid > heap.docids[0]))
            return;

        // Previously didn't enter heap. Insert
        if (key.score - diff < heap.scores[0] or (key.score - diff == heap.scores[0] and key.docid > heap.docids[0])) {
            heap.push_back(key);
            return;
        }

        // Was in the heap. Promote
        const where = heap.find(key);
        heap.promote(key, where);
    }

    pub fn results(self: *Self) []Result {
        for (0..self.len) |i|
            store[i] = .{ .docid = heap.docids[i], .score = heap.scores[i] };
        return store[0..self.len];
    }

    pub fn sorted(self: *Self) []Result {
        for (0..self.len) |i|
            store[i] = .{ .docid = heap.docids[i], .score = heap.scores[i] };
        std.sort.pdq(Result, store[0..self.len], {}, cmpResults);
        return store[0..self.len];
    }
};
