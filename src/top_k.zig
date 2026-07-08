// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const config = @import("config.zig");
const Result = @import("index.zig").Result;
const Heap = @import("heap.zig");
const Tournament = @import("tournament.zig");
const TopKTree = @import("top_k_tree.zig").TopKTree;

const default_top_k = fromName(config.default_top_k);
pub const default = if (default_top_k == .failed) @compileError(std.fmt.comptimePrint("Unknown top-k algorithm {s}", .{config.default_top_k})) else default_top_k;

pub const Alg = enum(u8) {
    none,
    heap,
    tournament,
    failed,
};

const alg_names = [_][]const u8{
    "none",
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

const Self = @This();

alg: Alg,
heap: TopKTree(Heap),
tournament: TopKTree(Tournament),

pub fn init(alg: Alg, accumulators: [*]config.AccumulatorType) Self {
    return .{
        .alg = alg,
        .heap = TopKTree(Heap).init(accumulators),
        .tournament = TopKTree(Tournament).init(accumulators),
    };
}

pub fn clearRetainingCapacity(self: *Self) void {
    self.heap.clearRetainingCapacity();
    self.tournament.clearRetainingCapacity();
}

pub fn insert(self: *Self, docid: u32, is: config.AccumulatorType, was: config.AccumulatorType) void {
    switch (self.alg) {
        .heap => self.heap.insert(docid, is, was),
        .tournament => self.tournament.insert(docid, is, was),
        else => unreachable,
    }
}

pub fn results(self: *Self, buf: []Result) []Result {
    return switch (self.alg) {
        .heap => self.heap.results(buf),
        .tournament => self.tournament.results(buf),
        else => unreachable,
    };
}
