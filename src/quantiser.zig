// QUANTISER.ZIG
// -------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

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

pub const Ranker = struct {
    const Self = @This();

    no_docs: f64 = 0,
    idf: f64 = 0, // log(N/df_t)
    avg_len: f64 = 0,

    pub fn init(no_docs: f64, avg_len: f64) Self {
        return .{ .no_docs = no_docs, .avg_len = avg_len };
    }

    pub fn compIdf(r: *Self, df: f64) void {
        r.idf = @log(r.no_docs / df);
    }

    pub fn compScore(r: *Self, tf: f64, doc_len: f64) f64 {
        return r.idf * (k1 + 1) * tf / (k1 * (1 - b + b * (doc_len / r.avg_len)) + tf);
    }
};
