// TOP_K_HEAP.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("index.zig").Result;
const heap = @import("heap.zig");

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

        heap.store[self.len] = key;
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
                heap.store[@intCast(where)].score = key.score;
                return;
            }
            // TODO handle unlikely case of querying 3rd term and heap isn't saturated

            heap.store[self.len] = key;
            self.len += 1;

            if (self.len == self.cap) {
                heap.make_heap();
                self.saturated = true;
            }

            return;
        }

        // Can't enter heap
        if (key.score < heap.store[0].score or (key.score == heap.store[0].score and key.docid > heap.store[0].docid))
            return;

        // Previously didn't enter heap. Insert
        if (key.score - diff < heap.store[0].score or (key.score - diff == heap.store[0].score and key.docid > heap.store[0].docid)) {
            heap.push_back(key);
            return;
        }

        // Was in the heap. Promote
        const where = heap.find(key);
        heap.promote(key, @intCast(where));
    }

    pub fn results(self: *Self) []Result {
        return heap.store[0..self.len];
    }

    pub fn sorted(self: *Self) []Result {
        std.sort.pdq(Result, heap.store[0..self.len], {}, cmpResults);
        return heap.store[0..self.len];
    }
};
