// TOP_K_HEAP.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("index.zig").Result;
const heap = @import("heap.zig");

var cache: [config.max_top_k]*u16 = undefined;

fn cmpResults(_: void, a: Result, b: Result) bool {
    // Score descending
    if (a.score != b.score)
        return a.score > b.score;

    // ID ascending
    return a.docid < b.docid;
}

pub const TopKHeap = struct {
    const Self = @This();

    accumulators: [*]u16,
    cap: u32 = config.max_top_k,
    len: u32 = 0,
    saturated: bool = false,

    pub fn init(accumulators: [*]u16) Self {
        return .{ .accumulators = accumulators };
    }

    pub fn clearRetainingCapacity(self: *Self) void {
        self.len = 0;
        self.saturated = false;
    }

    pub fn insert(self: *Self, docid: u32, is: u16, was: u16) void {
        // Heap requires more elements
        if (!self.saturated) {
            // First time this doc has been accumulated (new heap entry)
            if (was == 0) {
                cache[self.len] = &self.accumulators[docid];
                self.len += 1;

                if (self.len == self.cap) {
                    for (0..self.len) |i| {
                        heap.docids[i] = @intCast(cache[i] - self.accumulators);
                        heap.scores[i] = cache[i].*;
                    }
                    heap.make_heap();
                    self.saturated = true;
                }
            }

            return;
        }

        // Can't enter heap
        if (is < heap.scores[0] or (is == heap.scores[0] and docid > heap.docids[0]))
            return;

        // Previously didn't enter heap. Insert
        if (was < heap.scores[0] or (was == heap.scores[0] and docid > heap.docids[0])) {
            heap.push_back(docid, is);
            return;
        }

        // Was in the heap. Promote
        const where = heap.find(docid);
        heap.promote(docid, is, where);
    }

    pub fn results(self: *Self, buf: []Result) []Result {
        for (0..self.len) |i|
            buf[i] = .{ .docid = heap.docids[i], .score = heap.scores[i] };
        std.sort.pdq(Result, buf[0..self.len], {}, cmpResults);
        return buf[0..self.len];
    }
};
