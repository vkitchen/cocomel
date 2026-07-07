// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("index.zig").Result;
const heap = @import("heap.zig");

var cache: [config.max_top_k]*config.AccumulatorType = undefined;

fn cmpResults(_: void, a: Result, b: Result) bool {
    // Score descending
    if (a.score != b.score)
        return a.score > b.score;

    // ID ascending
    return a.docid < b.docid;
}

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
                self.top_k_lower_bound = heap.scores[0];
                self.saturated = true;
            }
        }

        return;
    }

    // Can't enter heap
    if (is < self.top_k_lower_bound or (is == self.top_k_lower_bound and docid > heap.docids[0]))
        return;

    // Previously didn't enter heap, or at bottom. Insert
    if (was < self.top_k_lower_bound or (was == self.top_k_lower_bound and docid >= heap.docids[0])) {
        heap.push_back(docid, is);
        self.top_k_lower_bound = heap.scores[0];
        return;
    }

    // Was in the heap. Promote
    const where = heap.find(docid);
    heap.promote(docid, is, where);
    self.top_k_lower_bound = heap.scores[0];
}

pub fn results(self: *Self, buf: []Result) []Result {
    for (0..self.len) |i|
        buf[i] = .{ .docid = heap.docids[i], .score = heap.scores[i] };
    std.sort.pdq(Result, buf[0..self.len], {}, cmpResults);
    return buf[0..self.len];
}
