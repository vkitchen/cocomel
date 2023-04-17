//	RANKING_FN_TFIDF.ZIG
//	--------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

// Reference: https://en.wikipedia.org/wiki/Tf–idf
//
// rsv_q = ∑(t∈q) log(N/df_t) * tf_td
//
// rsv_q the retrieval status value of the query is the summation of term scores
// N is the total number of documents in the collection
// df_t is the number of documents containing the term (document frequency)
// tf_td is the number of times the term occurs in the document

pub const Ranker = struct {
    const Self = @This();

    no_docs: f64 = 0,
    idf: f64 = 0, // log(N/df_t)

    pub fn init(no_docs: f64, _: f64) Self {
        return .{ .no_docs = no_docs };
    }

    pub fn compIdf(r: *Self, df: f64) void {
        r.idf = std.math.ln(r.no_docs / df);
    }

    pub fn compScore(r: *Self, tf: f64, _: f64) f64 {
        return r.idf * tf;
    }
};
