// INDEXER.ZIG
// -----------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const Dictionary = @import("dictionary.zig").Dictionary;
const Doc = @import("Doc.zig");
const serialise = @import("serialise_ccml.zig");
const stem = @import("stem.zig").stem;
const str = @import("str.zig");

const YesSnippets = struct {
    const Self = @This();

    indices: std.ArrayList(u32),
    file: std.Io.File,
    writer_buf: [4096]u8 = undefined,
    writer: std.Io.File.Writer,
    bytes_written: u32 = 0,

    fn init(io: std.Io) !Self {
        const file = try std.Io.Dir.cwd().createFile(io, config.files.snippets, .{});

        var self = Self{
            .indices = .empty,
            .file = file,
            .writer = undefined,
        };

        self.writer = file.writer(io, &self.writer_buf);

        return self;
    }

    fn addTerm(self: *Self, term: []u8) !void {
        try self.writer.interface.writeAll(term);
        try self.writer.interface.writeByte(' ');
        self.bytes_written += @truncate(term.len + 1);
    }

    fn newDocId(self: *Self, allocator: std.mem.Allocator) !void {
        try self.indices.append(allocator, self.bytes_written);
    }

    fn flush_and_close(self: *Self, io: std.Io, allocator: std.mem.Allocator) !void {
        try self.indices.append(allocator, self.bytes_written);
        try self.writer.interface.flush();

        self.file.close(io);
    }
};

const NoSnippets = struct {
    const Self = @This();

    indices: std.ArrayList(u32),

    fn init(_: std.Io) !Self {
        return .{ .indices = .empty };
    }
    fn addTerm(_: *Self, _: []u8) !void {}
    fn newDocId(_: *Self, _: std.mem.Allocator) !void {}
    fn flush_and_close(_: *Self, _: std.Io, _: std.mem.Allocator) !void {}
};

const Snippets = if (config.snippets) YesSnippets else NoSnippets;

pub const Indexer = struct {
    const Self = @This();

    buffer: [100]u8 = undefined,
    allocator: std.mem.Allocator,
    doc_ids: std.ArrayList(Doc),
    dict: Dictionary,
    snippets: Snippets,
    prev_term: ?[]u8 = null,

    pub fn init(io: std.Io, allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .doc_ids = .empty,
            .dict = try Dictionary.init(allocator),
            .snippets = try Snippets.init(io),
        };
    }

    pub fn addTerm(self: *Self, term: []u8) !void {
        try self.snippets.addTerm(term);

        var term_ = std.ascii.lowerString(term, term);
        term_ = str.stripPunct(term_, term_);
        term_ = stem(term_);

        try self.dict.insert(term_, @truncate(self.doc_ids.items.len - 1));
        if (self.prev_term) |prev| {
            var bigram = try self.allocator.alloc(u8, prev.len + 1 + term_.len);
            @memcpy(bigram[0..prev.len], prev);
            bigram[prev.len] = ' ';
            @memcpy(bigram[prev.len + 1 ..], term_);
            try self.dict.insert(bigram, @truncate(self.doc_ids.items.len - 1));
        }
        self.prev_term = try str.dup(self.allocator, term_);
        self.doc_ids.items[self.doc_ids.items.len - 1].len += 1;
    }

    pub fn addDocId(self: *Self, allocator: std.mem.Allocator, doc_id: []const u8) !void {
        self.prev_term = null;
        try self.snippets.newDocId(allocator);

        try self.doc_ids.append(self.allocator, .{ .name = try str.dup(self.allocator, doc_id) });
        if (self.doc_ids.items.len % 10000 == 0)
            std.debug.print("{d} Documents\n", .{self.doc_ids.items.len});
    }

    pub fn addTitle(self: *Self, title: []u8) !void {
        if (self.doc_ids.items[self.doc_ids.items.len - 1].title != null)
            return;
        self.doc_ids.items[self.doc_ids.items.len - 1].title = try str.dup(self.allocator, title);
    }

    pub fn write(self: *Self, io: std.Io, allocator: std.mem.Allocator) !void {
        try self.snippets.flush_and_close(io, allocator);

        std.debug.print("{s}\n", .{"Writing index..."});

        const index_file = try std.Io.Dir.cwd().createFile(io, config.files.index, .{});
        defer index_file.close(io);

        var writer_buf: [4096]u8 = undefined;
        var writer = index_file.writer(io, &writer_buf);

        const bytes_written = try serialise.write(&writer.interface, &self.doc_ids, &self.dict, &self.snippets.indices);
        try writer.flush();

        std.debug.print("Index is {d}B\n", .{bytes_written});
    }
};
