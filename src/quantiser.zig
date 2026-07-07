// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const index = @import("index.zig");

// Reference: https://github.com/Axiomatic314/ciffTools
// This is the Katelyn Harlan variant of uniform quantisation
// This variant was chosen as it keeps values in the range [1,255]
//
//                     x_t,d - L
// i_t = ⌊ (2^b - 2) * --------- + 1⌋
//                       U - L
//
// i_t the quantised impact
// b the number of bits to quantise into
// x_t,d the impact score of document d
// U the upper limit of impact scores
// L the lower limit of impact scores

const Self = @This();

min_rsv: f64,
max_rsv: f64,

pub fn init(min_rsv: f64, max_rsv: f64) Self {
    return .{ .min_rsv = min_rsv, .max_rsv = max_rsv };
}

pub fn quantise(self: *const Self, score: f64) index.ImpactType {
    const scale = (1 << config.quantise_bits) - 2;
    const res: index.ImpactType = @intFromFloat((score - self.min_rsv) / (self.max_rsv - self.min_rsv) * scale);
    return res + 1;
}
