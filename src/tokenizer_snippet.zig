//	TOKENIZER_SNIPPET.ZIG
//	---------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const stem = @import("stem.zig").stem;
const str = @import("str.zig");

pub const Term = struct {
    original: []u8,
    stemmed: []u8,
    hit: bool = false,
};

pub const Tokenizer = struct {
    const Self = @This();

    file: std.fs.File,
    start: usize = undefined,
    end: usize = undefined,
    buffer: [4096]u8 = undefined,
    result_buffer: [100]u8 = undefined, // TODO same size as config term length
    len: usize = undefined,
    index: usize = undefined,

    pub fn init(file: std.fs.File) Self {
        return .{ .file = file };
    }

    fn reinit(self: *Self, start: usize, end: usize) !void {
        self.start = start;
        self.end = end;
        self.index = 0;
        try self.file.seekTo(start);
        _ = try self.read();
    }

    fn read(self: *Self) !usize {
        self.len = try self.file.readAll(&self.buffer);
        self.index = 0;
        return self.len;
    }

    fn getChar(self: *Self) !u8 {
        if (self.start == self.end or self.len == 0)
            return 0;
        if (self.index == self.len)
            if (try self.read() == 0)
                return 0;
        const char = self.buffer[self.index];
        self.start += 1;
        self.index += 1;
        return char;
    }

    fn peek(self: *Self) !u8 {
        if (self.start == self.end or self.len == 0)
            return 0;
        if (self.index == self.len)
            if (try self.read() == 0)
                return 0;
        return self.buffer[self.index];
    }

    pub fn tokenize(self: *Self, allocator: std.mem.Allocator, result: *std.ArrayList(Term), start: usize, end: usize) !void {
        try self.reinit(start, end);

        var char: u8 = undefined;
        while (true) {
            char = try self.getChar();
            // EOF
            if (char == 0)
                break;
            // Text
            if (std.ascii.isAlphanumeric(char)) {
                var i: usize = 0;
                while (std.ascii.isAlphanumeric(char)) {
                    self.result_buffer[i] = char;
                    char = try self.getChar();
                    i += 1;
                }
                var toStem = try str.dup(allocator, self.result_buffer[0..i]);
                toStem = std.ascii.lowerString(toStem, toStem);
                try result.append(Term{
                    .original = try str.dup(allocator, self.result_buffer[0..i]),
                    .stemmed = stem(toStem),
                });
            }
        }
    }
};
