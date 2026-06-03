// INDEXER.ZIG
// -----------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("Doc.zig");
const CcmlSerialiser = @import("serialiser_ccml.zig").CcmlSerialiser;
const stem = @import("stem.zig").stem;
const str = @import("str.zig");

pub const Indexer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    serialiser: *CcmlSerialiser,
    buffer: [config.max_term_length]u8 = undefined,
    doc_ids: std.ArrayList(Doc),
    dict: Dictionary,
    bigrams: bool,
    prev_buffer: [config.max_term_length * 2 + 1]u8 = undefined,
    prev_len: usize = 0,
    has_prev: bool = false,

    pub fn init(allocator: std.mem.Allocator, serialiser: *CcmlSerialiser, bigrams: bool) !Self {
        return .{
            .allocator = allocator,
            .serialiser = serialiser,
            .doc_ids = .empty,
            .dict = try Dictionary.init(allocator),
            .bigrams = bigrams,
        };
    }

    pub fn addTerm(self: *Self, term: []u8) !void {
        try self.serialiser.addSnippetTerm(term);

        var term_ = std.ascii.lowerString(term, term);
        term_ = str.stripPunct(term_, term_);
        term_ = stem(term_);

        try self.dict.insert(term_, @truncate(self.doc_ids.items.len - 1));
        if (self.bigrams) {
            if (self.has_prev) {
                self.prev_buffer[self.prev_len] = ' ';
                @memcpy(self.prev_buffer[self.prev_len + 1 ..], term_);
                try self.dict.insert(self.prev_buffer[0 .. self.prev_len + 1 + term_.len], @truncate(self.doc_ids.items.len - 1));
            }
            @memcpy(self.prev_buffer[0..], term_);
            self.prev_len = term_.len;
            self.has_prev = true;
        }
        self.doc_ids.items[self.doc_ids.items.len - 1].len += 1;
    }

    pub fn addDocId(self: *Self, allocator: std.mem.Allocator, doc_id: []const u8) !void {
        self.has_prev = false;
        try self.serialiser.newDocId(allocator);

        try self.doc_ids.append(self.allocator, .{ .name = try str.dup(self.allocator, doc_id) });
        if (self.doc_ids.items.len % 10000 == 0)
            std.debug.print("{d} Documents\n", .{self.doc_ids.items.len});
    }

    pub fn addTitle(self: *Self, title: []u8) !void {
        if (self.doc_ids.items[self.doc_ids.items.len - 1].title != null)
            return;
        self.doc_ids.items[self.doc_ids.items.len - 1].title = try str.dup(self.allocator, title);
    }

    pub fn write(self: *Self, allocator: std.mem.Allocator) !void {
        std.debug.print("{s}\n", .{"Writing index..."});

        const bytes_written = try self.serialiser.write(allocator, &self.doc_ids, &self.dict);

        std.debug.print("Index is {d}B\n", .{bytes_written});
    }
};
