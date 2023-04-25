//	TOKENIZER_WSJ.ZIG
//	-----------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Indexer = @import("indexer.zig").Indexer;
const file = @import("file.zig");

pub fn WsjTokenizer(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        indexer: *Indexer,
        doc: ReaderType,
        index: usize = 0,
        len: usize = 0,
        buf: [4096]u8 = undefined,

        pub fn init(indexer: *Indexer, doc: ReaderType) !Self {
            return .{ .indexer = indexer, .doc = doc };
        }

        fn read(self: *Self) !void {
            self.len = try self.doc.read(&self.buf);
            self.index = 0;
        }

        fn eof(self: *Self) !bool {
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

        pub fn tokenize(self: *Self) !void {
            while (true) {
                const char = try self.peek();
                // EOF
                if (char == 0) {
                    return;
                }
                // Tag
                else if (char == '<') {
                    self.consume();
                    try self.consumeWhitespace();

                    // Doc ID
                    if (try self.consumeStr("DOCNO")) {
                        try self.consumeWhitespace();

                        if (try self.peek() == '>')
                            self.consume();

                        try self.consumeWhitespace();

                        var i: usize = 0;
                        while (i < self.indexer.buffer.len and (std.ascii.isAlphanumeric(try self.peek()) or try self.peek() == '-')) : (i += 1) {
                            self.indexer.buffer[i] = try self.peek();
                            self.consume();
                        }

                        try self.indexer.addDocId(self.indexer.buffer[0..i]);

                        continue;
                    } else {
                        while (try self.peek() != '>')
                            self.consume();
                        continue;
                    }
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
                else if (std.ascii.isAlpha(char)) {
                    var i: usize = 0;
                    while (i < self.indexer.buffer.len and std.ascii.isAlpha(try self.peek())) : (i += 1) {
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
