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

    pub fn reinit(self: *Self, doc: []const u8) void {
        self.index = 0;
        self.doc = doc;
    }

    pub fn next(self: *Self) Token {
        while (true) {
            // Whitespace
            while (self.index < self.doc.len and std.ascii.isWhitespace(self.doc[self.index])) {
                self.index += 1;
            }
            // EOF
            if (self.index == self.doc.len) {
                break;
            }
            // Number
            else if (std.ascii.isDigit(self.doc[self.index])) {
                var i: usize = 0;
                while (i < 256 and i + self.index < self.doc.len and std.ascii.isDigit(self.doc[self.index + i])) {
                    i += 1;
                }

                const out = Token{
                    .token = self.doc[self.index .. self.index + i],
                    .type = Token.Type.word,
                };

                self.index += i;

                return out;
            }
            // Word
            else if (std.ascii.isAlpha(self.doc[self.index])) {
                var i: usize = 0;
                while (i < 256 and i + self.index < self.doc.len and std.ascii.isAlpha(self.doc[self.index + i])) {
                    self.doc[i] = std.ascii.toLower(self.doc[i]);
                    i += 1;
                }

                const out = Token{
                    .token = self.doc[self.index .. self.index + i],
                    .type = Token.Type.word,
                };

                self.index += i;

                return out;
            }
            // Something else we don't want
            else {
                self.index += 1;
            }
        }
        const out = Token{
            .token = self.doc[0..0],
            .type = Token.Type.eof,
        };
        return out;
    }
};
