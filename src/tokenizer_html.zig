// TOKENIZER_HTML.ZIG
// ------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Indexer = @import("indexer.zig").Indexer;
const html = @import("html.zig");

fn isPunct(c: u8) bool {
    return c == '!' or c == '"' or c == '\'' or c == '(' or c == ')' or c == ',' or c == '-' or c == '.' or c == ';' or c == '?';
}

fn isWordChar(c: u8) bool {
    return std.ascii.isAlphabetic(c) or isPunct(c) or c == 0xE2;
}

pub const HtmlTokenizer = struct {
    const Self = @This();

    indexer: *Indexer,
    reader: *std.Io.Reader,

    pub fn init(indexer: *Indexer, reader: *std.Io.Reader) Self {
        return .{ .indexer = indexer, .reader = reader };
    }

    fn consumeWhitespace(self: *Self) !void {
        while (std.ascii.isWhitespace(try self.reader.peekByte()))
            self.reader.toss(1);
    }

    fn consumeStr(self: *Self, str: []const u8) !bool {
        for (str) |c| {
            if (try self.reader.peekByte() == c) {
                self.reader.toss(1);
            } else {
                return false;
            }
        }
        return true;
    }

    pub fn tokenize(self: *Self) !void {
        while (true) {
            const char = self.reader.peekByte() catch |err| {
                if (err == error.EndOfStream) return;
                return err;
            };

            // Tag
            if (char == '<') {
                self.reader.toss(1);
                if (try self.reader.peekByte() == 's') {
                    self.reader.toss(1);
                    if (try self.consumeStr("cript")) {
                        while (true) {
                            while (try self.reader.peekByte() != '<')
                                self.reader.toss(1);
                            if (try self.consumeStr("</script>")) {
                                break;
                            }
                        }
                        continue;
                    }
                    if (try self.consumeStr("tyle")) {
                        while (true) {
                            while (try self.reader.peekByte() != '<')
                                self.reader.toss(1);
                            if (try self.consumeStr("</style>")) {
                                break;
                            }
                        }
                        continue;
                    }
                }
                if (try self.consumeStr("title>")) {
                    var i: usize = 0;
                    while (i < self.indexer.buffer.len and try self.reader.peekByte() != '<') : (i += 1) {
                        // HTML escape
                        if (try self.reader.peekByte() == '&') {
                            var i_: usize = 0;
                            while (i + i_ < self.indexer.buffer.len and try self.reader.peekByte() != ';') : (i_ += 1)
                                self.indexer.buffer[i + i_] = try self.reader.takeByte();
                            // grab the ;
                            if (i + i_ < self.indexer.buffer.len and try self.reader.peekByte() == ';') {
                                self.indexer.buffer[i + i_] = try self.reader.takeByte();
                                i_ += 1;
                            }

                            i_ = try html.unescape(self.indexer.buffer[i .. i + i_]);

                            i += i_ - 1;
                            continue;
                        }

                        self.indexer.buffer[i] = try self.reader.takeByte();
                    }

                    try self.indexer.addTitle(self.indexer.buffer[0..i]);

                    while (try self.reader.peekByte() != '>')
                        self.reader.toss(1);
                    continue;
                }
                while (try self.reader.peekByte() != '>')
                    self.reader.toss(1);
                continue;
            }
            // HTML escape
            else if (char == '&') {
                var i: usize = 0;
                while (i < self.indexer.buffer.len and try self.reader.peekByte() != ';') : (i += 1)
                    self.indexer.buffer[i] = try self.reader.takeByte();
                // grab the ;
                if (i < self.indexer.buffer.len and try self.reader.peekByte() == ';') {
                    self.indexer.buffer[i] = try self.reader.takeByte();
                    i += 1;
                }

                i = try html.unescape(self.indexer.buffer[0..i]);

                try self.indexer.addTerm(self.indexer.buffer[0..i]);
                continue;
            }
            // Number
            else if (std.ascii.isDigit(char)) {
                var i: usize = 0;
                while (i < self.indexer.buffer.len and std.ascii.isDigit(try self.reader.peekByte())) : (i += 1)
                    self.indexer.buffer[i] = try self.reader.takeByte();

                try self.indexer.addTerm(self.indexer.buffer[0..i]);
                continue;
            }
            // Word
            else if (std.ascii.isAlphabetic(char)) {
                var i: usize = 0;
                while (i < self.indexer.buffer.len and isWordChar(try self.reader.peekByte())) : (i += 1) {
                    if (try self.reader.peekByte() == 0xE2) {
                        self.reader.toss(1);
                        if (try self.reader.peekByte() != 0x80)
                            continue;
                        self.reader.toss(1);
                        if (try self.reader.peekByte() != 0x99)
                            continue;
                        self.reader.toss(1);

                        self.indexer.buffer[i] = '\'';
                        continue;
                    }
                    self.indexer.buffer[i] = try self.reader.takeByte();
                }

                try self.indexer.addTerm(self.indexer.buffer[0..i]);
                continue;
            }
            self.reader.toss(1);
        }
    }
};
