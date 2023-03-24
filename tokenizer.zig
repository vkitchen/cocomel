//	TOKENIZER.ZIG
//	-------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

pub const TokenType = enum { docno, word, eof };

pub const Token = struct {
	token: []const u8,
	type: TokenType
};

pub const Tokenizer = struct {
	index: usize,
	length: usize,
	document: []const u8
};

pub fn init(t: *Tokenizer, document: []const u8) void {
    t.index = 0;
    t.length = document.len;
    t.document = document;
}

pub fn next(t: *Tokenizer) Token {
	while (true) {
		// Whitespace
		while (t.index < t.length and std.ascii.isWhitespace(t.document[t.index])) {
			t.index += 1;
		}
		// EOF
		if (t.index == t.length) {
			break;
		}
		else if (std.mem.startsWith(u8, t.document[t.index..], "<DOCNO>")) {
			t.index += std.mem.len("<DOCNO>");

			while(t.index < t.length and std.ascii.isWhitespace(t.document[t.index]))
				t.index += 1;

			var i: usize = 0;
			while (i < 256 and i + t.index < t.length and t.document[t.index + i] != '<' and !std.ascii.isWhitespace(t.document[t.index + i]))
				{
				i += 1;
				}

			const out = Token {
				.token = t.document[t.index..t.index+i],
				.type = TokenType.docno,
				};

			t.index += i;

			return out;
			}
		// Ignored tags
		else if (t.document[t.index] == '<')
			{
			t.index += 1;
			while (t.index < t.length and t.document[t.index] != '>')
				t.index += 1;
			t.index += 1;
			continue;
			}
		// Number
		else if (std.ascii.isDigit(t.document[t.index]))
			{
			var i: usize = 0;
			while (i < 256 and i + t.index < t.length and std.ascii.isDigit(t.document[t.index + i]))
				{
				i += 1;
				}

			const out = Token {
				.token = t.document[t.index..t.index+i],
				.type = TokenType.word,
				};

			t.index += i;

			return out;
			}
		// Word
		else if (std.ascii.isAlpha(t.document[t.index]))
			{
			var i: usize = 0;
			while (i < 256 and i + t.index < t.length and std.ascii.isAlpha(t.document[t.index + i]))
				{
				// buffer[i] = char_tolower(t.document[t.index + i]);
				i += 1;
				}

			const out = Token {
				.token = t.document[t.index..t.index+i],
				.type = TokenType.word,
				};

			t.index += i;

			return out;
			}
		// Something else we don't want
		else {
			t.index += 1;
		}

	}
	const out = Token {
		.token = t.document[0..0],
		.type = TokenType.eof,
		};
	return out;
}

