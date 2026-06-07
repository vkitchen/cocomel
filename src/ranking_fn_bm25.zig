// RANKING_FN_BM25.ZIG
// -------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");

// Reference: http://www.cs.otago.ac.nz/homepages/andrew/papers/2014-2.pdf
// This is the ATIRE variant of BM25. In emperical studies no variant performs substantially better
// This variant was chosen as it remains strictly positive and is therefore easier to work with
//
//                                          (k_1 + 1) * tf_td
// rsv_q = ∑(t∈q) log(N/df_t) * -----------------------------------------
//                              k_1 * (1 - b + b * (L_d / L_avg)) + tf_td
//
// rsv_q the retrieval status value of the query is the summation of term scores
// N is the total number of documents in the collection
// df_t is the number of documents containing the term (document frequency)
// tf_td is the number of times the term occurs in the document
// L_d is the total number of terms in the document i.e. document length
// L_avg is the average document length
// k_1 and b are tuning parameters
//
// N.B. The k_3 component is not used as it is assumed each term only occurs in the query only once

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
        return r.idf * (config.bm25_k1 + 1) * tf / (config.bm25_k1 * (1 - config.bm25_b + config.bm25_b * (doc_len / r.avg_len)) + tf);
    }
};
