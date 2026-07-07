// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const config = @import("config.zig");
const HashMap = @import("hash_map.zig").HashMap;
const Postings = @import("postings.zig");
const Doc = @import("doc.zig");
const Compressor = @import("compress_int.zig").Compressor;
const Stemmer = @import("stem.zig").Stemmer;
const CcmlSerialiser = @import("serialiser_ccml.zig");
const str = @import("str.zig");

const Self = @This();

stemmer: Stemmer,
serialiser: *CcmlSerialiser,
buffer: [config.max_term_length]u8 = undefined,
doc_ids: std.ArrayList(Doc),
vocab: HashMap(*Postings),

pub fn init(allocator: std.mem.Allocator, stemmer: Stemmer, serialiser: *CcmlSerialiser) !Self {
    return .{
        .stemmer = stemmer,
        .serialiser = serialiser,
        .doc_ids = .empty,
        .vocab = try HashMap(*Postings).init(allocator),
    };
}

pub fn addTerm(self: *Self, allocator: std.mem.Allocator, term: []u8) !void {
    try self.serialiser.addSnippetTerm(term);

    var term_ = std.ascii.lowerString(term, term);
    term_ = str.stripPunct(term_, term_);
    term_ = self.stemmer.stem(term_);

    if (term_.len == 0) return;

    const doc_id: u32 = @truncate(self.doc_ids.items.len - 1);

    const postings = try self.vocab.emplace(allocator, term_);
    if (postings.* == null) {
        const post = try allocator.create(Postings);
        post.* = Postings.init(doc_id);
        postings.* = post;
    } else {
        const post = postings.*.?;
        try post.append(allocator, doc_id);
    }

    self.doc_ids.items[self.doc_ids.items.len - 1].len += 1;
}

pub fn addDocId(self: *Self, allocator: std.mem.Allocator, doc_id: []const u8) !void {
    try self.serialiser.newDocId(allocator);

    try self.doc_ids.append(allocator, .{ .name = try allocator.dupe(u8, doc_id) });
    if (self.doc_ids.items.len % 10000 == 0)
        std.debug.print("{d} Documents\n", .{self.doc_ids.items.len});
}

pub fn addTitle(self: *Self, allocator: std.mem.Allocator, title: []u8) !void {
    if (self.doc_ids.items[self.doc_ids.items.len - 1].title.len != 0)
        return;
    self.doc_ids.items[self.doc_ids.items.len - 1].title = try allocator.dupe(u8, title);
}

pub fn write(self: *Self, io: std.Io, allocator: std.mem.Allocator, compressor: Compressor) !void {
    std.debug.print("{s}\n", .{"Writing index..."});

    const bytes_written = try self.serialiser.write(io, allocator, &self.doc_ids, &self.vocab, compressor, self.stemmer.algorithm, true);

    std.debug.print("Index size {Bi:.2}\n", .{bytes_written});
}
