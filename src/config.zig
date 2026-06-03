// CONFIG.ZIG
// ----------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

pub const index_name = "index.ccml";
pub const index_version = 1;

pub const socket_name = "/tmp/cocomel.sock";

// tf-idf, bm25
pub const ranking_fn = "bm25";

// s, none
pub const stemmer = "s";

pub const io_buffer_size = 4096;
pub const max_term_length = 100; // longest token from document
pub const max_query_length = 1000; // chars in query
pub const max_query_terms = 100; // words in query
