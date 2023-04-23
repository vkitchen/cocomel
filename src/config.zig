//	CONFIG.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

pub const files = .{
    .index = "index.ccml",
    .snippets = "snippets.ccml",
};

// true, false
pub const snippets = true;

// tf-idf, bm25
pub const ranking_fn = "bm25";

// s, none
pub const stemmer = "s";

pub const max_query_length = 1000; // chars in query
pub const max_query_terms = 100; // words in query
