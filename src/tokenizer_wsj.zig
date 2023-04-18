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

    pub fn tokenize(t: *Self) !void {
        while (true) {
            // Whitespace
            while (t.index < t.doc.len and std.ascii.isWhitespace(t.doc[t.index])) {
                t.index += 1;
            }
            // EOF
            if (t.index == t.doc.len) {
                return;
            }
            // Doc ID
            else if (std.mem.startsWith(u8, t.doc[t.index..], "<DOCNO>")) {
                t.index += std.mem.len("<DOCNO>");

                while (t.index < t.doc.len and std.ascii.isWhitespace(t.doc[t.index]))
                    t.index += 1;

                var i: usize = 0;
                while (i + t.index < t.doc.len and t.doc[t.index + i] != '<' and !std.ascii.isWhitespace(t.doc[t.index + i]))
                    i += 1;

                try t.indexer.addDocId(t.doc[t.index .. t.index + i]);

                t.index += i;

                continue;
            }
            // Ignored tags
            else if (t.doc[t.index] == '<') {
                t.index += 1;
                while (t.index < t.doc.len and t.doc[t.index] != '>')
                    t.index += 1;
                t.index += 1;
                continue;
            }
            // Number
            else if (std.ascii.isDigit(t.doc[t.index])) {
                var i: usize = 0;
                while (t.index + i < t.doc.len and std.ascii.isDigit(t.doc[t.index + i]))
                    i += 1;

                try t.indexer.addTerm(t.doc[t.index .. t.index + i]);

                t.index += i;

                continue;
            }
            // Word
            else if (std.ascii.isAlpha(t.doc[t.index])) {
                var i: usize = 0;
                while (t.index + i < t.doc.len and std.ascii.isAlpha(t.doc[t.index + i])) {
                    t.doc[t.index + i] = std.ascii.toLower(t.doc[t.index + i]);
                    i += 1;
                }

                try t.indexer.addTerm(t.doc[t.index .. t.index + i]);

                t.index += i;

                continue;
            }
            // Something else we don't want
            else {
                t.index += 1;
            }
        }
    }
};
