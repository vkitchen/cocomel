// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("result.zig");
const Heap = @import("heap.zig");
const Tournament = @import("tournament.zig");
const TopKInsert = @import("top_k_insert.zig");
const TopKTree = @import("top_k_tree.zig").TopKTree;

const TopKHeap = TopKTree(Heap);
const TopKTournament = TopKTree(Tournament);

const default_top_k = fromName(config.default_top_k);
pub const default = if (default_top_k == .failed) @compileError(std.fmt.comptimePrint("Unknown top-k algorithm {s}", .{config.default_top_k})) else default_top_k;

pub const Alg = enum(u8) {
    none,
    insert,
    heap,
    tournament,
    failed,
};

const alg_names = [_][]const u8{
    "none",
    "insert",
    "heap",
    "tournament",
};

pub fn fromName(alg: []const u8) Alg {
    for (alg_names, 0..) |name, i| {
        if (std.mem.eql(u8, alg, name))
            return @enumFromInt(i);
    }

    return .failed;
}

var cache: [config.max_top_k]*config.AccumulatorType = undefined;

const Self = @This();

alg: Alg,
saturated: bool = undefined,
cap: u32 = config.max_top_k,
len: u32 = undefined,
accumulators: [*]config.AccumulatorType,

fn cmpResults(_: void, a: Result, b: Result) bool {
    // Score descending
    if (a.score != b.score)
        return a.score > b.score;

    // ID ascending
    return a.docid < b.docid;
}

pub fn init(alg: Alg, accumulators: [*]config.AccumulatorType) Self {
    return .{
        .alg = alg,
        .accumulators = accumulators,
    };
}

pub fn clearRetainingCapacity(self: *Self) void {
    self.len = 0;
    self.saturated = false;
}

pub fn insert(self: *Self, docid: u32, is: config.AccumulatorType, was: config.AccumulatorType) void {
    switch (self.alg) {
        .insert => {
            if (!self.saturated) {
                // First time this doc has been accumulated (new entry)
                if (was == 0) {
                    cache[self.len] = &self.accumulators[docid];
                    self.len += 1;

                    if (self.len == self.cap) {
                        TopKInsert.clearRetainingCapacity();
                        for (0..self.len) |i|
                            TopKInsert.append(@intCast(cache[i] - self.accumulators), cache[i].*);
                        TopKInsert.make();

                        self.saturated = true;
                    }
                }

                return;
            }

            TopKInsert.insert(docid, is, was);
        },
        .heap => {
            if (!self.saturated) {
                // First time this doc has been accumulated (new entry)
                if (was == 0) {
                    cache[self.len] = &self.accumulators[docid];
                    self.len += 1;

                    if (self.len == self.cap) {
                        TopKHeap.clearRetainingCapacity();
                        for (0..self.len) |i|
                            TopKHeap.append(@intCast(cache[i] - self.accumulators), cache[i].*);
                        TopKHeap.make();

                        self.saturated = true;
                    }
                }

                return;
            }

            TopKHeap.insert(docid, is, was);
        },
        .tournament => {
            if (!self.saturated) {
                // First time this doc has been accumulated (new entry)
                if (was == 0) {
                    cache[self.len] = &self.accumulators[docid];
                    self.len += 1;

                    if (self.len == self.cap) {
                        TopKTournament.clearRetainingCapacity();
                        for (0..self.len) |i|
                            TopKTournament.append(@intCast(cache[i] - self.accumulators), cache[i].*);
                        TopKTournament.make();

                        self.saturated = true;
                    }
                }

                return;
            }

            TopKTournament.insert(docid, is, was);
        },
        else => unreachable,
    }
}

pub fn results(self: *Self, buf: []Result) []Result {
    if (!self.saturated) {
        for (0..self.len) |i|
            buf[i] = .{ .docid = @intCast(cache[i] - self.accumulators), .score = cache[i].* };
        return buf[0..self.len];
    }

    switch (self.alg) {
        .insert => TopKInsert.extract(buf),
        .heap => TopKHeap.extract(buf),
        .tournament => TopKTournament.extract(buf),
        else => unreachable,
    }

    std.sort.pdq(Result, buf[0..self.len], {}, cmpResults);
    return buf[0..self.len];
}
