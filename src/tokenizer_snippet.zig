//	TOKENIZER_SNIPPET.ZIG
//	---------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const stem = @import("stem.zig").stem;
const str = @import("str.zig");

pub const Term = struct {
    original: []const u8,
    stemmed: []u8,
    hit: bool = false,
};

pub const Tokenizer = struct {
    const Self = @This();

    snippets: []const u8,
    index: usize,
    end: usize,

    pub fn init(snippets: []const u8, start: usize, end: usize) Self {
        return .{ .snippets = snippets, .index = start, .end = end };
    }

    pub fn tokenize(self: *Self, allocator: std.mem.Allocator, result: *std.ArrayListUnmanaged(Term)) !void {
        while (true) : (self.index += 1) {
            // EOF
            if (self.index >= self.end)
                break;
            // Text
            if (std.ascii.isAlphanumeric(self.snippets[self.index])) {
                var i: usize = 1;
                while (self.index + i < self.end and std.ascii.isAlphanumeric(self.snippets[self.index + i]))
                    i += 1;

                var stemmed = try str.dup(allocator, self.snippets[self.index .. self.index + i]);
                stemmed = std.ascii.lowerString(stemmed, stemmed);

                result.appendAssumeCapacity(Term{
                    .original = self.snippets[self.index .. self.index + i],
                    .stemmed = stem(stemmed),
                });

                self.index += i;
            }
        }
    }
};
