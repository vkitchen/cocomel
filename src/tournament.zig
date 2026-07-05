// TOURNAMENT.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const config = @import("config.zig");

pub var len: usize = 0;
pub const cap = config.max_top_k;

pub const cap_rounded = (config.max_top_k + 7) / 8 * 8;
const KMask = @Int(.unsigned, cap_rounded);

const Node = struct {
    score: config.AccumulatorType = 0,
    winner: usize, // pointer to leaf
    loser: usize, // pointer to leaf
};

pub var docids: [cap]u32 = undefined;
pub var tree: [cap * 2]Node = undefined;

fn parent(i: usize) usize {
    return i / 2;
}

fn leftOf(i: usize) usize {
    return i * 2;
}

fn rightOf(i: usize) usize {
    return i * 2 + 1;
}

// Tree is saturated highest impact lowest docid first
// Therefore a value is considered less than if it has lower score or higher docid
fn lt(a: usize, b: usize) bool {
    return tree[a].score < tree[b].score or (tree[a].score == tree[b].score and docids[a - cap] > docids[b - cap]);
}

fn match(a: usize, b: usize) [2]usize {
    if (lt(a, b))
        return .{ a, b };
    return .{ b, a };
}

pub fn make() void {
    // Build the loser tree right to left, bottom to top (makes maths easier)
    var i: u16 = cap * 2 - 2;
    while (i > 0) : (i -= 2) {
        const winner, const loser = match(tree[i].winner, tree[i + 1].winner);
        const p = parent(i);
        tree[p] = .{ .winner = winner, .loser = loser };
    }

    // Overall winner
    tree[0] = tree[1];
}

// Replace the overall winner
pub fn replace(docid: u32, score: config.AccumulatorType) void {
    const pos = tree[0].winner;

    docids[pos - cap] = docid;
    tree[pos].score = score;

    var new = tree[pos];

    var p = parent(pos);
    while (p != 0) {
        const winner, const loser = match(new.winner, tree[p].loser);
        new = tree[winner];
        tree[p] = .{ .winner = winner, .loser = loser };

        p = parent(p);
    }
    // Store the new root
    tree[0].winner = new.winner;
}

pub fn append(docid: u32, score: config.AccumulatorType) void {
    if (len == cap)
        return;

    docids[len] = docid;
    tree[len + cap].winner = len + cap;
    tree[len + cap].loser = len + cap;
    tree[len + cap].score = score;
    len += 1;
}

// TODO is there a cleaner way to do this?
// Promote an existing element with its new score
pub fn promote(pos: u64, score: config.AccumulatorType) void {
    tree[pos + cap].score = score;
    var new = tree[pos + cap];

    var p = parent(pos + cap);
    while (p != 0) {
        if (tree[p].loser == pos + cap) {
            tree[p].loser = new.loser;
            break;
        }
        const winner, const loser = match(new.winner, tree[p].loser);
        new = tree[winner];
        tree[p] = .{ .winner = winner, .loser = loser };

        p = parent(p);
    }
}

pub fn bottomDoc() u32 {
    return docids[tree[0].winner - cap];
}

pub fn find(docid: u32) u64 {
    const Vec = @Vector(cap_rounded, u32);

    const haystack: Vec = docids;
    const needle: Vec = @splat(docid);

    const mask = haystack == needle;
    const bits: KMask = @bitCast(mask);

    return @ctz(bits);
}
