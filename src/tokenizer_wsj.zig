// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Indexer = @import("indexer.zig");

const Self = @This();

indexer: *Indexer,
reader: *std.Io.Reader,

pub fn init(indexer: *Indexer, reader: *std.Io.Reader) !Self {
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

pub fn tokenize(self: *Self, allocator: std.mem.Allocator) !void {
    while (true) {
        const char = self.reader.peekByte() catch |err| {
            if (err == error.EndOfStream) return;
            return err;
        };

        // Tag
        if (char == '<') {
            self.reader.toss(1);
            try self.consumeWhitespace();

            // Doc ID
            if (try self.consumeStr("DOCNO")) {
                try self.consumeWhitespace();

                if (try self.reader.peekByte() == '>')
                    self.reader.toss(1);

                try self.consumeWhitespace();

                var i: usize = 0;
                while (i < self.indexer.buffer.len and (std.ascii.isAlphanumeric(try self.reader.peekByte()) or try self.reader.peekByte() == '-')) : (i += 1)
                    self.indexer.buffer[i] = try self.reader.takeByte();

                try self.indexer.addDocId(allocator, self.indexer.buffer[0..i]);

                continue;
            } else {
                while (try self.reader.peekByte() != '>')
                    self.reader.toss(1);
                continue;
            }
        }
        // Number
        else if (std.ascii.isDigit(char)) {
            var i: usize = 0;
            while (i < self.indexer.buffer.len and std.ascii.isDigit(try self.reader.peekByte())) : (i += 1)
                self.indexer.buffer[i] = try self.reader.takeByte();

            try self.indexer.addTerm(allocator, self.indexer.buffer[0..i]);
            continue;
        }
        // Word
        else if (std.ascii.isAlphabetic(char)) {
            var i: usize = 0;
            while (i < self.indexer.buffer.len and std.ascii.isAlphabetic(try self.reader.peekByte())) : (i += 1)
                self.indexer.buffer[i] = try self.reader.takeByte();

            try self.indexer.addTerm(allocator, self.indexer.buffer[0..i]);
            continue;
        }
        self.reader.toss(1);
    }
}
