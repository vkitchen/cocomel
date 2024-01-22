//	INDEXER.ZIG
//	-----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

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
    file: std.fs.File,
    buf: std.io.BufferedWriter(4096, std.fs.File.Writer),
    bytes_written: u32 = 0,

    fn init(allocator: std.mem.Allocator) !Self {
        const file = try std.fs.cwd().createFile(config.files.snippets, .{});
        const buf = std.io.bufferedWriter(file.writer());

        return .{
            .indices = std.ArrayList(u32).init(allocator),
            .file = file,
            .buf = buf,
        };
    }

    fn addTerm(self: *Self, term: []u8) !void {
        try self.buf.writer().writeAll(term);
        try self.buf.writer().writeByte(' ');
        self.bytes_written += @truncate(term.len + 1);
    }

    fn newDocId(self: *Self) !void {
        try self.indices.append(self.bytes_written);
    }

    fn flush_and_close(self: *Self) !void {
        try self.indices.append(self.bytes_written);
        try self.buf.flush();

        self.file.close();
    }
};

const NoSnippets = struct {
    const Self = @This();

    indices: std.ArrayList(u32),

    fn init(allocator: std.mem.Allocator) !Self {
        return .{ .indices = std.ArrayList(u32).init(allocator) };
    }
    fn addTerm(_: *Self, _: []u8) !void {}
    fn newDocId(_: *Self) !void {}
    fn flush_and_close(_: *Self) !void {}
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

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .doc_ids = std.ArrayList(Doc).init(allocator),
            .dict = try Dictionary.init(allocator),
            .snippets = try Snippets.init(allocator),
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
            @memcpy(bigram, prev);
            bigram[prev.len] = ' ';
            @memcpy(bigram[prev.len + 1 ..], term_);
            try self.dict.insert(bigram, @truncate(self.doc_ids.items.len - 1));
        }
        self.prev_term = try str.dup(self.allocator, term_);
        self.doc_ids.items[self.doc_ids.items.len - 1].len += 1;
    }

    pub fn addDocId(self: *Self, doc_id: []u8) !void {
        self.prev_term = null;
        try self.snippets.newDocId();

        try self.doc_ids.append(.{ .name = try str.dup(self.allocator, doc_id) });
        if (self.doc_ids.items.len % 10000 == 0)
            std.debug.print("{d} Documents\n", .{self.doc_ids.items.len});
    }

    pub fn addTitle(self: *Self, title: []u8) !void {
        if (self.doc_ids.items[self.doc_ids.items.len - 1].title != null)
            return;
        self.doc_ids.items[self.doc_ids.items.len - 1].title = try str.dup(self.allocator, title);
    }

    pub fn write(self: *Self) !void {
        try self.snippets.flush_and_close();

        std.debug.print("{s}\n", .{"Writing index..."});

        const index_file = try std.fs.cwd().createFile(config.files.index, .{});
        defer index_file.close();
        var index_buf = std.io.bufferedWriter(index_file.writer());

        const bytes_written = try serialise.write(index_buf.writer(), &self.doc_ids, &self.dict, &self.snippets.indices);
        try index_buf.flush();

        std.debug.print("Index is {d}B\n", .{bytes_written});
    }
};
