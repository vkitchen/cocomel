// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("index.zig").Result;

var cache: [config.max_top_k]*config.AccumulatorType = undefined;

fn cmpResults(_: void, a: Result, b: Result) bool {
    // Score descending
    if (a.score != b.score)
        return a.score > b.score;

    // ID ascending
    return a.docid < b.docid;
}

pub fn TopKTree(comptime T: type) type {
    return struct {
        const Self = @This();

        accumulators: [*]config.AccumulatorType,
        cap: u32 = config.max_top_k,
        len: u32 = 0,
        saturated: bool = false,

        // cache the lower bound for performance
        min_score: config.AccumulatorType = undefined,
        min_docid: u32 = undefined,

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
                        T.len = 0;
                        for (0..self.len) |i|
                            T.append(@intCast(cache[i] - self.accumulators), cache[i].*);
                        T.make();
                        self.min_score = T.minScore();
                        self.min_docid = T.minDocid();
                        self.saturated = true;
                    }
                }

                return;
            }

            // Can't enter tree
            if (is < self.min_score or (is == self.min_score and docid > self.min_docid))
                return;

            // Previously didn't enter tree. Or is bottom of tree. Insert
            if (was < self.min_score or (was == self.min_score and docid >= self.min_docid)) {
                T.insert(docid, is);
                self.min_score = T.minScore();
                self.min_docid = T.minDocid();
                return;
            }

            // Was in the tree. Promote (can't affect root)
            T.promote(docid, is);
        }

        pub fn results(self: *Self, buf: []Result) []Result {
            if (self.saturated) {
                T.extract(buf);
            } else {
                for (0..self.len) |i|
                    buf[i] = .{ .docid = @intCast(cache[i] - self.accumulators), .score = cache[i].* };
            }
            std.sort.pdq(Result, buf[0..self.len], {}, cmpResults);
            return buf[0..self.len];
        }
    };
}
