// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("result.zig");

pub var len: usize = 0;
pub const cap = config.max_top_k;

const cap_rounded = (config.max_top_k + 7) / 8 * 8;
const KMask = @Int(.unsigned, cap_rounded);

const Node = struct {
    i: u16, // pointer to leaf
    score: config.AccumulatorType,
};

pub var docids: [cap_rounded]u32 = undefined;
pub var tree: [cap * 2]Node = undefined;

pub fn minScore() config.AccumulatorType {
    return tree[0].score;
}

pub fn minDocid() u32 {
    return docids[tree[0].i - cap];
}

fn parent(i: usize) usize {
    return i / 2;
}

// Tree is saturated highest impact lowest docid first
// Therefore a value is considered less than if it has lower score or higher docid
inline fn lt(a: Node, b: Node) bool {
    return a.score < b.score or (a.score == b.score and docids[a.i - cap] > docids[b.i - cap]);
}

fn match(a: Node, b: Node) [2]Node {
    if (lt(a, b))
        return .{ a, b };
    return .{ b, a };
}

pub fn make() void {
    // We vs winners but ultimately only store losers. Here we keep the match results
    var winners: [cap * 2]Node = undefined;

    // Populate with leaf nodes
    for (cap..cap * 2) |i|
        winners[i] = tree[i];

    // Build the loser tree right to left, bottom to top (makes maths easier)
    var i: usize = cap * 2 - 2;
    while (i > 0) : (i -= 2) {
        const winner, const loser = match(winners[i], winners[i + 1]);
        const p = parent(i);
        winners[p] = winner;
        tree[p] = loser;
    }

    // The overall winner forms the root
    tree[0] = winners[1];
}

pub fn append(docid: u32, score: config.AccumulatorType) void {
    if (len == cap)
        return;

    docids[len] = docid;
    tree[len + cap] = .{ .i = @truncate(len + cap), .score = score };
    len += 1;
}

// Replace the overall winner
pub fn insert(docid: u32, score: config.AccumulatorType) void {
    const pos = tree[0].i;

    docids[pos - cap] = docid;
    tree[pos].score = score;

    var winner = tree[pos];

    var p = parent(pos);
    while (p != 0) {
        // Swap with nodes we no longer beat
        if (lt(tree[p], winner)) {
            const tmp = winner;
            winner = tree[p];
            tree[p] = tmp;
        }

        p = parent(p);
    }

    // Store the new root
    tree[0] = winner;
}

// Promote an existing element with its new score
fn update(pos: u64, score: config.AccumulatorType) void {
    tree[pos + cap].score = score;

    var winner = tree[pos + cap];

    var p = parent(pos + cap);
    while (p != 0) {
        // When we see ourselves we know we were disqualified from future matches and we're done
        if (tree[p].i == pos + cap) {
            tree[p] = winner;
            return;
        }

        // Swap with nodes we no longer beat
        if (lt(tree[p], winner)) {
            const tmp = winner;
            winner = tree[p];
            tree[p] = tmp;
        }

        p = parent(p);
    }
}

fn find(docid: u32) u64 {
    const Vec = @Vector(cap_rounded, u32);

    const haystack: Vec = docids;
    const needle: Vec = @splat(docid);

    const mask = haystack == needle;
    const bits: KMask = @bitCast(mask);

    return @ctz(bits);
}

pub fn promote(docid: u32, score: config.AccumulatorType) void {
    const where = find(docid);
    update(where, score);
}

pub fn extract(buf: []Result) void {
    for (0..len) |i|
        buf[i] = .{ .docid = docids[i], .score = tree[i + len].score };
}
