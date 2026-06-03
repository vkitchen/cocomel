// TOKENIZER_HTML.ZIG
// ------------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Indexer = @import("indexer.zig").Indexer;
const html = @import("html.zig");

pub const HtmlTokenizer = struct {
    const Self = @This();

    indexer: *Indexer,
    reader: *std.Io.Reader,

    pub fn init(indexer: *Indexer, reader: *std.Io.Reader) Self {
        return .{ .indexer = indexer, .reader = reader };
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

    fn consumeEscape(self: *Self, start: usize) !usize {
        var i: usize = 0;
        while (start + i < self.indexer.buffer.len and try self.reader.peekByte() != ';') : (i += 1)
            self.indexer.buffer[start + i] = try self.reader.takeByte();
        // grab the ;
        if (start + i < self.indexer.buffer.len and try self.reader.peekByte() == ';') {
            self.indexer.buffer[start + i] = try self.reader.takeByte();
            i += 1;
        }

        return try html.unescape(self.indexer.buffer[start .. start + i]);
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
                    while (i < self.indexer.buffer.len and try self.reader.peekByte() != '<') {
                        // HTML escape
                        if (try self.reader.peekByte() == '&') {
                            i += try self.consumeEscape(i);
                            continue;
                        }

                        self.indexer.buffer[i] = try self.reader.takeByte();
                        i += 1;
                    }

                    try self.indexer.addTitle(self.indexer.buffer[0..i]);

                    while (try self.reader.peekByte() != '>')
                        self.reader.toss(1);

                    self.reader.toss(1);
                    continue;
                }
                while (try self.reader.peekByte() != '>')
                    self.reader.toss(1);

                self.reader.toss(1);
                continue;
            }
            // Word
            else if (!std.ascii.isWhitespace(char)) {
                var i: usize = 0;
                while (i < self.indexer.buffer.len and !std.ascii.isWhitespace(try self.reader.peekByte()) and try self.reader.peekByte() != '<') {
                    // HTML escape
                    if (try self.reader.peekByte() == '&') {
                        i += try self.consumeEscape(i);
                        continue;
                    }

                    self.indexer.buffer[i] = try self.reader.takeByte();
                    i += 1;
                }

                try self.indexer.addTerm(self.indexer.buffer[0..i]);
                continue;
            }

            self.reader.toss(1);
        }
    }
};
