// CONFIG.ZIG
// ----------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

pub const index_name = "index.ccml";

pub const socket_name = "/tmp/cocomel.sock";

// Values are taken from ATIRE which was tuned on classic TREC collections
// Reference: https://github.com/andrewtrotman/ATIRE/blob/master/source/ranking_function_bm25.h
// Reference: https://www.elastic.co/blog/practical-bm25-part-3-considerations-for-picking-b-and-k1-in-elasticsearch
pub const bm25_k1 = 0.9; // Term saturation
pub const bm25_b = 0.4; // Document length normalisation

// s, none
pub const stemmer = "s";

pub const io_buffer_size = 4096;
pub const max_term_length = 100; // longest token from document
pub const max_query_length = 1000; // chars in query
pub const max_query_terms = 100; // words in query
