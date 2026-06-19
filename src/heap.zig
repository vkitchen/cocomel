// HEAP.ZIG
// --------
// Copyright (c) Xian-Fei Jia, Andrew Trotman, Vaughan Kitchen
// Released under the 2-clause BSD license (See: https://en.wikipedia.org/wiki/BSD_licenses)
//
// Originally from the ATIRE code base where it was written by Xiang-Fei Jia and Andrew Trotman
// Stolen from JASSv2 https://github.com/andrewtrotman/JASSv2/blob/master/source/heap.h
// Modified for use in cocomel by Vaughan Kitchen

const config = @import("config.zig");
const Result = @import("index.zig").Result;

pub var store: [config.max_top_k]Result = undefined;

fn swap(left: usize, right: usize) void {
    const tmp = store[left];
    store[left] = store[right];
    store[right] = tmp;
}

fn left_of(position: usize) usize {
    return (position << 1) + 1;
}

fn right_of(position: usize) usize {
    return (position << 1) + 2;
}

// Heap is saturated highest impact lowest docid first
// Therefore a value is considered less than if it has lower score or higher docid
fn lt(a: Result, b: Result) bool {
    return a.score < b.score or (a.score == b.score and a.docid > b.docid);
}

fn lteq(a: Result, b: Result) bool {
    return a.score < b.score or (a.score == b.score and a.docid >= b.docid);
}

fn gt(a: Result, b: Result) bool {
    return a.score > b.score or (a.score == b.score and a.docid < b.docid);
}

fn heapify(position: usize) void {
    var smallest: usize = undefined;

    const left = left_of(position);
    const right = right_of(position);

    if (left < config.max_top_k and lt(store[left], store[position])) {
        smallest = left;
    } else {
        smallest = position;
    }

    if (right < config.max_top_k and lt(store[right], store[smallest]))
        smallest = right;

    if (smallest != position) {
        swap(position, smallest);
        heapify(smallest);
    }
}

fn insert_from(key: Result, index: usize) void {
    var position = index;

    while (position < config.max_top_k) {
        const left = left_of(position);
        const right = right_of(position);

        // check store out of bound, it's also the stopping condition
        if (left < config.max_top_k and right < config.max_top_k) {
            if (lteq(key, store[left]) and lteq(key, store[right])) {
                break; // we're smaller then the left and the right so we're done
            } else if (lt(store[left], store[right])) {
                store[position] = store[left];
                position = left;
            } else {
                store[position] = store[right];
                position = right;
            }
        } else if (left < config.max_top_k) { // and right > size (because this is an else)
            if (gt(key, store[left])) {
                store[position] = store[left];
                position = left;
            } else {
                break;
            }
        } else {
            break; // both right and left exceed end of store
        }
    }

    store[position] = key;
}

pub fn make_heap() void {
    var position: i64 = config.max_top_k / 2 - 1;
    while (position >= 0) {
        heapify(@intCast(position));
        position -= 1;
    }
}

pub fn push_back(key: Result) void {
    insert_from(key, 0);
}

pub fn find(key: Result) i64 {
    for (0..config.max_top_k) |position|
        if (store[position].docid == key.docid)
            return @intCast(position);

    return -1;
}

pub fn promote(key: Result, position: usize) void {
    insert_from(key, position);
}
