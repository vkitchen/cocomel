//	TOKENIZER_WSJ.ZIG
//	-----------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Indexer = @import("indexer.zig").Indexer;
const file = @import("file.zig");

pub const WsjTokenizer = struct {
    const Self = @This();

    indexer: *Indexer,
    doc: []u8,
    index: usize = 0,

    pub fn init(allocator: std.mem.Allocator, indexer: *Indexer, filename: []u8) !Self {
        var doc = try file.slurp(allocator, filename);
        return .{
            .indexer = indexer,
            .doc = doc,
        };
    }

    pub fn tokenize(self: *Self) !void {
        while (true) {
            // Whitespace
            while (self.index < self.doc.len and std.ascii.isWhitespace(self.doc[self.index])) {
                self.index += 1;
            }
            // EOF
            if (self.index == self.doc.len) {
                return;
            }
            // Doc ID
            else if (std.mem.startsWith(u8, self.doc[self.index..], "<DOCNO>")) {
                self.index += std.mem.len("<DOCNO>");

                while (self.index < self.doc.len and std.ascii.isWhitespace(self.doc[self.index]))
                    self.index += 1;

                var i: usize = 0;
                while (i + self.index < self.doc.len and self.doc[self.index + i] != '<' and !std.ascii.isWhitespace(self.doc[self.index + i]))
                    i += 1;

                try self.indexer.addDocId(self.doc[self.index .. self.index + i]);

                self.index += i;

                continue;
            }
            // Ignored tags
            else if (self.doc[self.index] == '<') {
                self.index += 1;
                while (self.index < self.doc.len and self.doc[self.index] != '>')
                    self.index += 1;
                self.index += 1;
                continue;
            }
            // Number
            else if (std.ascii.isDigit(self.doc[self.index])) {
                var i: usize = 0;
                while (self.index + i < self.doc.len and std.ascii.isDigit(self.doc[self.index + i]))
                    i += 1;

                try self.indexer.addCleanTerm(self.doc[self.index .. self.index + i]);

                self.index += i;

                continue;
            }
            // Word
            else if (std.ascii.isAlpha(self.doc[self.index])) {
                var i: usize = 0;
                while (self.index + i < self.doc.len and std.ascii.isAlpha(self.doc[self.index + i])) {
                    self.doc[self.index + i] = std.ascii.toLower(self.doc[self.index + i]);
                    i += 1;
                }

                try self.indexer.addCleanTerm(self.doc[self.index .. self.index + i]);

                self.index += i;

                continue;
            }
            // Something else we don't want
            else {
                self.index += 1;
            }
        }
    }
};
