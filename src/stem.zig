//	STEM.ZIG
//	--------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const stemmer = @import("config.zig").stemmer;
const s = @import("stem_s.zig").stem;

pub fn none(term: []u8) []u8 {
    return term;
}

pub const stem = if (std.mem.eql(u8, stemmer, "s")) s else none;
