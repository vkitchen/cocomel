// INDEX.ZIG
// ---------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const hash = @import("dictionary.zig").hash;
const snippets = @import("snippets.zig");
const vbyte = @import("compress_int_vbyte.zig");
const Stemmer = @import("stem.zig").Stemmer;

pub const version = 1;

pub const Result = struct {
    doc_id: u32,
    score: u16,
};

fn read16(buf: []const u8, offset: usize) u16 {
    return std.mem.bytesToValue(u16, buf[offset .. offset + @sizeOf(u16)][0..2]);
}

fn read32(buf: []const u8, offset: usize) u32 {
    return std.mem.bytesToValue(u32, buf[offset .. offset + @sizeOf(u32)][0..4]);
}

fn readStr(buf: []const u8, offset: usize) []const u8 {
    const len = read16(buf, offset);
    const start = offset + @sizeOf(u16);
    return buf[start .. start + len];
}

fn readArray(buf: []const u8, offset: usize) []const u32 {
    const len = read32(buf, offset);
    const start = offset + @sizeOf(u32);
    return @alignCast(std.mem.bytesAsSlice(u32, buf[start .. start + len * @sizeOf(u32)]));
}

pub const Header = packed struct {
    stemmer: Stemmer.Alg,
    docs_count: u32,
    docs_offset: u32,
    dictionary_offset: u32,
    snippets_offset: u32,
    max_doc_length: u32,
    version: u16,
};

pub const Index = struct {
    const Self = @This();

    index: []const u8,
    header: *align(1) const Header,
    docs: []const u32,
    dictionary: []const u32,
    snippets: []const u32,

    pub fn init(index: []const u8) !Self {
        const header = std.mem.bytesAsValue(Header, index[index.len - @bitSizeOf(Header) / 8 ..]);

        if (header.version != version) {
            std.debug.print("Incorrect index version\n", .{});
            std.process.exit(1);
        }

        return .{
            .index = index,
            .header = header,
            .docs = readArray(index, header.docs_offset),
            .dictionary = readArray(index, header.dictionary_offset),
            .snippets = if (header.snippets_offset != 0) readArray(index, header.snippets_offset) else &.{},
        };
    }

    pub fn hasSnippets(self: *const Self) bool {
        return self.header.snippets_offset != 0;
    }

    // [   u16   ][ []u8 ][   u16   ][ []u8 ]
    // [ strlen  ][ str  ][ strlen  ][ str  ]
    pub fn name(self: *const Self, doc_id: u32) [2][]const u8 {
        const name_offset = self.docs[doc_id];
        const doc_name = readStr(self.index, name_offset);
        const title_offset = name_offset + @sizeOf(u16) + doc_name.len;
        const title = readStr(self.index, title_offset);
        return .{ doc_name, title };
    }

    pub fn snippet(self: *const Self, doc_id: u32) [2]u32 {
        return [2]u32{ self.snippets[doc_id], self.snippets[doc_id + 1] };
    }

    pub fn chunkScore(self: *const Self, offset: u32) u8 {
        if (read32(self.index, offset) == 0) return 0;
        return self.index[offset + @sizeOf(u32)];
    }

    pub fn processChunk(self: *const Self, offset: u32, results: []Result) u32 {
        const ids_len = read32(self.index, offset);
        const score = self.index[offset + @sizeOf(u32)];
        const ids = offset + @sizeOf(u32) + @sizeOf(u8);

        var i: u32 = 0;
        var last_id: u32 = 0;
        while (i < ids_len) {
            var doc_id: u32 = 0;
            i += vbyte.read(self.index[ids + i ..], &doc_id);
            doc_id += last_id;
            results[doc_id].score += score;
            last_id = doc_id;
        }

        return offset + @sizeOf(u32) + @sizeOf(u8) + ids_len;
    }

    pub fn find(self: *const Self, key: []const u8) u32 {
        var i = hash(key, @truncate(self.dictionary.len));
        while (true) {
            if (self.dictionary[i] == 0)
                return 0;
            const term = readStr(self.index, self.dictionary[i]);
            if (std.mem.eql(u8, term, key))
                return @truncate(self.dictionary[i] + @sizeOf(u16) + term.len);

            i = i + 1 & (@as(u32, @truncate(self.dictionary.len)) - 1);
        }
    }
};
