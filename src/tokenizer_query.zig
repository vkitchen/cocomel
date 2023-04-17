//	TOKENIZER_QUERY.ZIG
//	-------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Token = @import("tokenizer.zig").Token;

pub const QueryTokenizer = struct {
    const Self = @This();

    index: usize,
    doc: []u8,

    pub fn init(doc: []u8) Self {
        return .{ .index = 0, .doc = doc };
    }

    pub fn reinit(t: *Self, doc: []const u8) void {
        t.index = 0;
        t.doc = doc;
    }

    pub fn next(t: *Self) Token {
        while (true) {
            // Whitespace
            while (t.index < t.doc.len and std.ascii.isWhitespace(t.doc[t.index])) {
                t.index += 1;
            }
            // EOF
            if (t.index == t.doc.len) {
                break;
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
                    t.doc[i] = std.ascii.toLower(t.doc[i]);
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
