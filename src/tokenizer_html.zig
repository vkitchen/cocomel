//	TOKENIZER_HTML.ZIG
//	------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Indexer = @import("indexer.zig").Indexer;

fn isPunct(c: u8) bool {
    return c == '!' or c == '"' or c == '\'' or c == '(' or c == ')' or c == ',' or c == '-' or c == '.' or c == ';' or c == '?';
}

fn isWordChar(c: u8) bool {
    return std.ascii.isAlphabetic(c) or isPunct(c) or c == 0xE2;
}

pub fn HtmlTokenizer(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        indexer: *Indexer,
        doc: *ReaderType = undefined,
        buf: [512]u8 = undefined, // Tar block size
        index: usize = 0,
        len: usize = 0,
        file_size: usize = 0,

        pub fn init(indexer: *Indexer) Self {
            return .{ .indexer = indexer };
        }

        fn read(self: *Self) !void {
            self.len = try self.doc.read(&self.buf);
            self.index = 0;
        }

        fn eof(self: *Self) !bool {
            if (self.file_size == 0)
                return true;
            if (self.index >= self.len)
                try self.read();
            return self.len == 0;
        }

        fn peek(self: *Self) !u8 {
            if (try self.eof())
                return 0;
            return self.buf[self.index];
        }

        fn consume(self: *Self) void {
            self.index += 1;
            self.file_size -|= 1;
        }

        fn consumeWhitespace(self: *Self) !void {
            while (std.ascii.isWhitespace(try self.peek()))
                self.consume();
        }

        fn consumeStr(self: *Self, str: []const u8) !bool {
            for (str) |c| {
                if (try self.peek() == c) {
                    self.consume();
                } else {
                    return false;
                }
            }
            return true;
        }

        pub fn tokenize(self: *Self, doc: *ReaderType, file_size: u64) !void {
            self.doc = doc;
            self.file_size = file_size;
            try self.read();

            while (true) {
                const char = try self.peek();
                // EOF
                if (char == 0) {
                    return;
                }
                // Tag
                else if (char == '<') {
                    self.consume();
                    if (try self.peek() == 's') {
                        self.consume();
                        if (try self.consumeStr("cript") or try self.consumeStr("tyle")) {
                            while (try self.peek() != '<')
                                self.consume();
                        }
                    }
                    if (try self.consumeStr("title>")) {
                        var i: usize = 0;
                        while (i < self.indexer.buffer.len and try self.peek() != '<') : (i += 1) {
                            self.indexer.buffer[i] = try self.peek();
                            self.consume();
                        }

                        try self.indexer.addTitle(self.indexer.buffer[0..i]);

                        while (try self.peek() != '>')
                            self.consume();
                        continue;
                    }
                    while (try self.peek() != '>')
                        self.consume();
                    continue;
                }
                // Number
                else if (std.ascii.isDigit(char)) {
                    var i: usize = 0;
                    while (i < self.indexer.buffer.len and std.ascii.isDigit(try self.peek())) : (i += 1) {
                        self.indexer.buffer[i] = try self.peek();
                        self.consume();
                    }

                    try self.indexer.addTerm(self.indexer.buffer[0..i]);
                    continue;
                }
                // Word
                else if (std.ascii.isAlphabetic(char)) {
                    var i: usize = 0;
                    while (i < self.indexer.buffer.len and isWordChar(try self.peek())) : (i += 1) {
                        if (try self.peek() == 0xE2) {
                            self.consume();
                            if (try self.peek() != 0x80)
                                continue;
                            self.consume();
                            if (try self.peek() != 0x99)
                                continue;
                            self.consume();

                            self.indexer.buffer[i] = '\'';
                            continue;
                        }
                        self.indexer.buffer[i] = try self.peek();
                        self.consume();
                    }

                    try self.indexer.addTerm(self.indexer.buffer[0..i]);
                    continue;
                }
                self.consume();
            }
        }
    };
}
