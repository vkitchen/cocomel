//	TOKENIZER.ZIG
//	-------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

pub const Token = struct {
    pub const Type = enum { docno, word, eof };

    token: []const u8,
    type: Type,
};

pub const Tokenizer = struct {
    index: usize,
    doc: []const u8,

    pub fn init(doc: []const u8) Tokenizer {
        return .{ .index = 0, .doc = doc };
    }

    pub fn reinit(t: *Tokenizer, doc: []const u8) void {
        t.index = 0;
        t.doc = doc;
    }

    pub fn next(t: *Tokenizer) Token {
        while (true) {
            // Whitespace
            while (t.index < t.doc.len and std.ascii.isWhitespace(t.doc[t.index])) {
                t.index += 1;
            }
            // EOF
            if (t.index == t.doc.len) {
                break;
            } else if (std.mem.startsWith(u8, t.doc[t.index..], "<DOCNO>")) {
                t.index += std.mem.len("<DOCNO>");

                while (t.index < t.doc.len and std.ascii.isWhitespace(t.doc[t.index]))
                    t.index += 1;

                var i: usize = 0;
                while (i < 256 and i + t.index < t.doc.len and t.doc[t.index + i] != '<' and !std.ascii.isWhitespace(t.doc[t.index + i])) {
                    i += 1;
                }

                const out = Token{
                    .token = t.doc[t.index .. t.index + i],
                    .type = Token.Type.docno,
                };

                t.index += i;

                return out;
            }
            // Ignored tags
            else if (t.doc[t.index] == '<') {
                t.index += 1;
                while (t.index < t.doc.len and t.doc[t.index] != '>')
                    t.index += 1;
                t.index += 1;
                continue;
            }
            // Number
            else if (std.ascii.isDigit(t.doc[t.index])) {
                var i: usize = 0;
                while (i < 256 and i + t.index < t.doc.len and std.ascii.isDigit(t.doc[t.index + i])) {
                    i += 1;
                }

                const out = Token{
                    .token = t.doc[t.index .. t.index + i],
                    .type = Token.Type.word,
                };

                t.index += i;

                return out;
            }
            // Word
            else if (std.ascii.isAlpha(t.doc[t.index])) {
                var i: usize = 0;
                while (i < 256 and i + t.index < t.doc.len and std.ascii.isAlpha(t.doc[t.index + i])) {
                    // buffer[i] = char_tolower(t.doc[t.index + i]);
                    i += 1;
                }

                const out = Token{
                    .token = t.doc[t.index .. t.index + i],
                    .type = Token.Type.word,
                };

                t.index += i;

                return out;
            }
            // Something else we don't want
            else {
                t.index += 1;
            }
        }
        const out = Token{
            .token = t.doc[0..0],
            .type = Token.Type.eof,
        };
        return out;
    }
};