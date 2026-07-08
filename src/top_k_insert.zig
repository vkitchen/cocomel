// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const config = @import("config.zig");

const Result = @import("result.zig");

pub var store: [config.max_top_k]Result = undefined;

fn lt(a: Result, b: Result) bool {
    return a.score < b.score or (a.score == b.score and a.docid > b.docid);
}

fn cmpResults(_: void, a: Result, b: Result) bool {
    return lt(b, a);
}

var len: u32 = undefined;

pub fn clearRetainingCapacity() void {
    len = 0;
}

pub fn append(docid: u32, score: config.AccumulatorType) void {
    store[len] = .{ .docid = docid, .score = score };
    len += 1;
}

pub fn make() void {
    std.sort.pdq(Result, store[0..len], {}, cmpResults);
}

pub fn insert(docid: u32, is: config.AccumulatorType, _: config.AccumulatorType) void {
    const key: Result = .{ .docid = docid, .score = is };
    const worst: Result = store[len - 1];

    // Can't make top-k
    if (lt(key, worst))
        return;

    // Find insert spot
    var i: usize = 0;
    while (i < len and lt(key, store[i]))
        i += 1;

    // Swap our new doc in
    var bumped = store[i];
    store[i] = key;
    i += 1;

    // Shuffle down remainder
    while (i < len) : (i += 1) {
        // We upgraded this doc and are now done
        if (key.docid == bumped.docid)
            return;

        const tmp = store[i];
        store[i] = bumped;
        bumped = tmp;
    }
}

pub fn extract(buf: []Result) void {
    for (0..len) |i|
        buf[i] = store[i];
}
