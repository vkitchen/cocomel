//	TOKENIZER_QUERY.ZIG
//	-------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const stem = @import("stem.zig").stem;

pub const Term = struct {
    pub const Type = enum { word, phrase };

    term: []u8,
    type: Type,
    neg: bool,
};

const Token = struct {
    const Type = enum { eof, word, neg, quote };

    token: []u8 = undefined,
    type: Type,
};

const Tokenizer = struct {
    const Self = @This();

    index: usize = 0,
    raw: []u8,

    fn init(raw: []u8) Self {
        return .{ .raw = raw };
    }

    fn eof(self: *Self) bool {
        return self.index == self.raw.len;
    }

    fn peek(self: *Self) u8 {
        if (self.eof())
            return 0;
        return self.raw[self.index];
    }

    fn consume(self: *Self) void {
        self.index += 1;
    }

    fn next(self: *Self) Token {
        while (true) {
            const char = self.peek();
            // EOF
            if (char == 0) {
                return .{ .type = .eof };
            }
            // Negated term
            else if (char == '-') {
                self.consume();
                return .{ .type = .neg };
            }
            // Phrase
            else if (char == '"') {
                self.consume();
                return .{ .type = .quote };
            }
            // Number
            else if (std.ascii.isDigit(char)) {
                const start = self.index;
                var end = self.index;
                while (std.ascii.isDigit(self.peek())) : (end += 1)
                    self.consume();

                return .{ .type = .word, .token = self.raw[start..end] };
            }
            // Word
            else if (std.ascii.isAlpha(char)) {
                const start = self.index;
                var end = self.index;
                while (std.ascii.isAlpha(self.peek())) : (end += 1)
                    self.consume();

                return .{ .type = .word, .token = self.raw[start..end] };
            }
            self.consume();
        }
    }
};

pub const Parser = struct {
    const Self = @This();

    index: usize = 0,
    raw: []u8,
    query: *std.ArrayListUnmanaged(Term),
    toker: Tokenizer,

    pub fn init(store: *std.ArrayListUnmanaged(Term), raw: []u8) Self {
        return .{ .query = store, .raw = raw, .toker = Tokenizer.init(raw) };
    }

    pub fn parse(self: *Self) void {
        var is_neg = false;
        var is_phrase = false;
        var phrase_start: usize = 0;
        while (true) {
            const tok = self.toker.next();
            if (tok.type == .eof) {
                return;
            } else if (tok.type == .neg) {
                is_neg = true;
            } else if (tok.type == .quote) {
                if (is_phrase) {
                    self.query.appendAssumeCapacity(.{ .type = .phrase, .term = self.raw[phrase_start..self.index], .neg = is_neg });
                    is_phrase = false;
                } else {
                    is_phrase = true;
                    phrase_start = self.index;
                }
            } else if (tok.type == .word) {
                if (phrase_start != self.index) {
                    self.raw[self.index] = ' ';
                    self.index += 1;
                }
                var term = std.ascii.lowerString(self.raw[self.index..], tok.token);
                term = stem(term);
                self.index += term.len;
                if (!is_phrase) {
                    self.query.appendAssumeCapacity(.{ .type = .word, .term = term, .neg = is_neg });
                    is_neg = false;
                }
            }
        }
    }

    pub fn print(self: *Self) void {
        for (self.query.items) |q| {
            switch (q.type) {
                .word => std.debug.print("Term Word neg? {}: '{s}'\n", .{ q.neg, q.term }),
                .phrase => std.debug.print("Term Phrase neg? {}: '{s}'\n", .{ q.neg, q.term }),
            }
        }
    }
};
