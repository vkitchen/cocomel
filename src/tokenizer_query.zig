// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const Stemmer = @import("stem.zig").Stemmer;

pub const Term = struct {
    term: []u8,
    count: u32,
};

pub const Parser = struct {
    const Self = @This();

    stemmer: Stemmer,
    index: usize = 0,
    raw: []u8,
    query: *std.ArrayListUnmanaged(Term),

    pub fn init(stemmer: Stemmer, store: *std.ArrayListUnmanaged(Term), raw: []u8) Self {
        return .{ .stemmer = stemmer, .query = store, .raw = raw };
    }

    pub fn parse(self: *Self) void {
        while (self.index < self.raw.len) {
            // Number
            if (std.ascii.isDigit(self.raw[self.index])) {
                var end: usize = self.index + 1;
                while (end < self.raw.len and std.ascii.isDigit(self.raw[end]))
                    end += 1;

                var term = std.ascii.lowerString(self.raw[self.index..], self.raw[self.index..end]);
                term = self.stemmer.stem(term);
                self.index += term.len;
                self.query.appendAssumeCapacity(.{ .term = term, .count = 1 });
                continue;
            }
            // Word
            else if (std.ascii.isAlphabetic(self.raw[self.index])) {
                var end: usize = self.index + 1;
                while (end < self.raw.len and std.ascii.isAlphabetic(self.raw[end]))
                    end += 1;

                var term = std.ascii.lowerString(self.raw[self.index..], self.raw[self.index..end]);
                term = self.stemmer.stem(term);
                self.index += term.len;
                self.query.appendAssumeCapacity(.{ .term = term, .count = 1 });
                continue;
            }
            self.index += 1;
        }
    }
};
