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

    store: []Result,
    cap: u32 = config.max_top_k,
    len: u32 = 0,
    saturated: bool = false,

    pub fn init(store: []Result) Self {
        return .{ .store = store };
    }

    pub fn clearRetainingCapacity(self: *Self) void {
        self.len = 0;
        self.saturated = false;
        @memset(heap.docids[0..heap.top_k_rounded], 0);
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
            // First time this doc has been accumulated
            if (key.score - diff == 0) {
                heap.docids[self.len] = key.docid;
                heap.scores[self.len] = key.score;
                self.len += 1;

                if (self.len == self.cap) {
                    heap.make_heap();
                    self.saturated = true;
                }
                return;
            }

            // Was in the heap? Promote
            const where = heap.find(key);
            if (where != -1) {
                heap.scores[@intCast(where)] = key.score;
            } else {
                heap.docids[self.len] = key.docid;
                heap.scores[self.len] = key.score;
                self.len += 1;

                if (self.len == self.cap) {
                    heap.make_heap();
                    self.saturated = true;
                }
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
        heap.promote(key, @intCast(where));
    }

    pub fn results(self: *Self) []Result {
        self.store.len = self.len;
        for (0..self.len) |i|
            self.store[i] = .{ .docid = heap.docids[i], .score = heap.scores[i] };
        std.sort.pdq(Result, self.store, {}, cmpResults);
        return self.store;
    }
};
