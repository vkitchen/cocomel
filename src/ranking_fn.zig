//	RANKING_FN.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const ranking_fn = @import("config.zig").ranking_fn;
const bm25 = @import("ranking_fn_bm25.zig").Ranker;
const tfidf = @import("ranking_fn_tf-idf.zig").Ranker;

pub const Ranker = if (std.mem.eql(u8, ranking_fn, "tf-idf")) tfidf else bm25;
