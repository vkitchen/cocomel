// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const Result = @import("result.zig");

const c = @import("c");

var store: [1_500_000]Result align(32) = undefined;
var cap: usize = undefined;

fn memset(dest: []align(32) u8) void {
    c.memset_avx2(dest.ptr, dest.len);
}

// https://stackoverflow.com/questions/664014/what-integer-hash-function-are-good-that-accepts-an-integer-hash-key
fn hash(key: u32) u32 {
    var x = key;
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = (x >> 16) ^ x;
    return x;
}

pub fn resize(len: usize) void {
    cap = len;
    memset(std.mem.sliceAsBytes(store[0..len]));
}

pub fn append(docid: u32, impact: u32) void {
    var i = hash(docid) % cap;
    while (store[i].docid != 0)
        i = (i + 1) % cap;

    store[i] = .{ .docid = docid, .score = impact };
}

pub fn promote(docid: u32, impact: u32) void {
    var i = hash(docid) % cap;
    while (store[i].docid != 0) {
        if (store[i].docid == docid) {
            store[i].score += impact;
            return;
        }

        i = i + 1 % cap;
    }
}

fn cmpResult(_: void, a: Result, b: Result) bool {
    return a.score > b.score;
}

pub fn results() []Result {
    std.sort.pdq(Result, store[0..cap], {}, cmpResult);
    return store[0..cap];
}
