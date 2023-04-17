//	TOKENIZER.ZIG
//	-------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

pub const Token = struct {
    pub const Type = enum { docno, word, none, eof };

    token: []u8,
    type: Type,
};
