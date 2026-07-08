// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

pub const index_name = "index.ccml";
pub const socket_name = "/tmp/cocomel.sock";
pub const scratch_name = "scratch.ccml"; // used briefly during index serialisation

pub const default_compressor = "bp128";
pub const default_top_k = "heap";

// Maximum amount of the collection to examine before giving up on a query
pub const SearchProportion = 0.1;

// Used for search. If you regularly have queries above 8 terms I recommend u16
pub const AccumulatorType = u8;

// Used for offsets into sections of the index
// This may break things if set below u64
// TODO detect breakage during serialisation
pub const FileOffsetType = u32;

// u16 may offer a slight increase in precision but slows indexing
pub const TermFrequencyType = u8;

// Values above 8 use u16 impacts which slows search with minimal gains to precision
pub const quantise_bits = 8;

// Values are taken from ATIRE which was tuned on classic TREC collections
// Reference: https://github.com/andrewtrotman/ATIRE/blob/master/source/ranking_function_bm25.h
// Reference: https://www.elastic.co/blog/practical-bm25-part-3-considerations-for-picking-b-and-k1-in-elasticsearch
pub const bm25_k1 = 0.9; // Term saturation
pub const bm25_b = 0.4; // Document length normalisation

pub const io_buffer_size = 4096;
pub const max_top_k = 1000;
pub const max_term_length = 100; // longest token from document
pub const max_query_length = 1000; // chars in query
pub const max_query_terms = 100; // words in query
