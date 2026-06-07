// STEM.ZIG
// --------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const s = @import("stem_s.zig").stem;

pub const Stemmer = struct {
    pub const Alg = enum(u8) {
        none,
        s,
    };

    const Self = @This();

    algorithm: Alg,

    pub fn init(algorithm: Alg) Self {
        return .{ .algorithm = algorithm };
    }

    pub fn stem(self: *const Self, term: []u8) []u8 {
        return switch (self.algorithm) {
            .none => term,
            .s => s(term),
        };
    }
};
