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

pub const top_k_rounded = (config.max_top_k + 7) / 8 * 8;
const KMask = @Int(.unsigned, top_k_rounded);

pub var docids: [top_k_rounded]u32 = [_]u32{0} ** top_k_rounded; // Rounded for SIMD
pub var scores: [config.max_top_k]u16 = undefined;

fn swap(left: usize, right: usize) void {
    const tmp_docid = docids[left];
    docids[left] = docids[right];
    docids[right] = tmp_docid;

    const tmp_score = scores[left];
    scores[left] = scores[right];
    scores[right] = tmp_score;
}

fn left_of(position: usize) usize {
    return (position << 1) + 1;
}

fn right_of(position: usize) usize {
    return (position << 1) + 2;
}

// Heap is saturated highest impact lowest docid first
// Therefore a value is considered less than if it has lower score or higher docid
fn lt(a: usize, b: usize) bool {
    return scores[a] < scores[b] or (scores[a] == scores[b] and docids[a] > docids[b]);
}

fn lteq(a: Result, b: usize) bool {
    return a.score < scores[b] or (a.score == scores[b] and a.docid >= docids[b]);
}

fn gt(a: Result, b: usize) bool {
    return a.score > scores[b] or (a.score == scores[b] and a.docid < docids[b]);
}

fn heapify(position: usize) void {
    var smallest: usize = undefined;

    const left = left_of(position);
    const right = right_of(position);

    if (left < config.max_top_k and lt(left, position)) {
        smallest = left;
    } else {
        smallest = position;
    }

    if (right < config.max_top_k and lt(right, smallest))
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
            if (lteq(key, left) and lteq(key, right)) {
                break; // we're smaller then the left and the right so we're done
            } else if (lt(left, right)) {
                docids[position] = docids[left];
                scores[position] = scores[left];
                position = left;
            } else {
                docids[position] = docids[right];
                scores[position] = scores[right];
                position = right;
            }
        } else if (left < config.max_top_k) { // and right > size (because this is an else)
            if (gt(key, left)) {
                docids[position] = docids[left];
                scores[position] = scores[left];
                position = left;
            } else {
                break;
            }
        } else {
            break; // both right and left exceed end of store
        }
    }

    docids[position] = key.docid;
    scores[position] = key.score;
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
    const Vec = @Vector(top_k_rounded, u32);

    const haystack: Vec = docids;
    const needle: Vec = @splat(key.docid);

    const mask = haystack == needle;
    const bits: KMask = @bitCast(mask);

    if (bits != 0)
        return @ctz(bits);

    return -1;
}

pub fn promote(key: Result, position: usize) void {
    insert_from(key, position);
}
