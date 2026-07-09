// Copyright (c) Xian-Fei Jia, Andrew Trotman, Vaughan Kitchen
// Released under the 2-clause BSD license (https://opensource.org/license/bsd-2-clause)
//
// Originally from the ATIRE code base where it was written by Xiang-Fei Jia and Andrew Trotman
// Stolen from JASSv2 https://github.com/andrewtrotman/JASSv2/blob/master/source/heap.h
// Modified for use in cocomel by Vaughan Kitchen

const config = @import("config.zig");
const Result = @import("result.zig");

const c = @import("c");

pub var len: usize = 0;
pub var cap: usize = undefined;

pub const max_top_k_rounded = (config.max_top_k + 7) / 8 * 8;
const KMask = @Int(.unsigned, max_top_k_rounded);

pub var docids: [max_top_k_rounded]u32 = [_]u32{0} ** max_top_k_rounded; // Rounded for SIMD
pub var scores: [config.max_top_k]config.AccumulatorType = undefined;

pub fn minScore() config.AccumulatorType {
    return scores[0];
}

pub fn minDocid() u32 {
    return docids[0];
}

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

fn lteq(docid: u32, score: u16, cmp: usize) bool {
    return score < scores[cmp] or (score == scores[cmp] and docid >= docids[cmp]);
}

fn gt(docid: u32, score: u16, cmp: usize) bool {
    return score > scores[cmp] or (score == scores[cmp] and docid < docids[cmp]);
}

fn heapify(position: usize) void {
    var smallest: usize = undefined;

    const left = left_of(position);
    const right = right_of(position);

    if (left < cap and lt(left, position)) {
        smallest = left;
    } else {
        smallest = position;
    }

    if (right < cap and lt(right, smallest))
        smallest = right;

    if (smallest != position) {
        swap(position, smallest);
        heapify(smallest);
    }
}

fn insert_from(docid: u32, score: config.AccumulatorType, index: usize) void {
    var position = index;

    while (position < cap) {
        const left = left_of(position);
        const right = right_of(position);

        // check store out of bound, it's also the stopping condition
        if (left < cap and right < cap) {
            if (lteq(docid, score, left) and lteq(docid, score, right)) {
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
        } else if (left < cap) { // and right > size (because this is an else)
            if (gt(docid, score, left)) {
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

    docids[position] = docid;
    scores[position] = score;
}

pub fn make() void {
    for (cap..max_top_k_rounded) |i|
        docids[i] = 0;

    var position: i64 = config.max_top_k / 2 - 1;
    while (position >= 0) {
        heapify(@intCast(position));
        position -= 1;
    }
}

pub fn append(docid: u32, score: config.AccumulatorType) void {
    if (len == cap)
        return;

    docids[len] = docid;
    scores[len] = score;
    len += 1;
}

pub fn insert(docid: u32, score: config.AccumulatorType) void {
    insert_from(docid, score, 0);
}

pub fn promote(docid: u32, score: config.AccumulatorType) void {
    const where = c.find_avx2(&docids, len, docid);
    insert_from(docid, score, @intCast(where));
}

pub fn extract(buf: []Result) void {
    for (0..cap) |i|
        buf[i] = .{ .docid = docids[i], .score = scores[i] };
}
