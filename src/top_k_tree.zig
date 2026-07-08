// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("result.zig");

var min_score: config.AccumulatorType = undefined;
var min_docid: u32 = undefined;

pub fn TopKTree(comptime T: type) type {
    return struct {
        pub fn clearRetainingCapacity() void {
            T.len = 0;
        }

        pub fn append(docid: u32, score: config.AccumulatorType) void {
            T.append(docid, score);
        }

        pub fn make() void {
            T.make();
            min_score = T.minScore();
            min_docid = T.minDocid();
        }

        pub fn insert(docid: u32, is: config.AccumulatorType, was: config.AccumulatorType) void {
            // Can't enter tree
            if (is < min_score or (is == min_score and docid > min_docid))
                return;

            // Previously didn't enter tree. Or is bottom of tree. Insert
            if (was < min_score or (was == min_score and docid >= min_docid)) {
                T.insert(docid, is);
                min_score = T.minScore();
                min_docid = T.minDocid();
                return;
            }

            // Was in the tree. Promote (can't affect root)
            T.promote(docid, is);
        }

        pub fn extract(buf: []Result) void {
            T.extract(buf);
        }
    };
}
