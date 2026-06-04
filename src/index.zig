// INDEX.ZIG
// ---------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const config = @import("config.zig");
const hash = @import("dictionary.zig").hash;
const snippets = @import("snippets.zig");
const vbyte = @import("compress_int_vbyte.zig");

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
    const str_len = read16(buf, offset);
    const str_start = offset + @sizeOf(u16);
    return buf[str_start .. str_start + str_len];
}

pub const Header = packed struct {
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

    pub fn init(index: []const u8) !Self {
        const header = std.mem.bytesAsValue(Header, index[index.len - @bitSizeOf(Header) / 8 ..]);

        if (header.version != config.index_version) {
            std.debug.print("Incorrect index version\n", .{});
            std.process.exit(1);
        }

        return .{
            .index = index,
            .header = header,
        };
    }

    pub fn hasSnippets(self: *const Self) bool {
        return self.header.snippets_offset != 0;
    }

    // [   u16   ][ []u8 ][   u16   ][ []u8 ]
    // [ strlen  ][ str  ][ strlen  ][ str  ]
    pub fn name(self: *const Self, doc_id: u32) [2][]const u8 {
        const stride = doc_id * @sizeOf(u32);
        const name_offset = read32(self.index, self.header.docs_offset + stride);
        const doc_name = readStr(self.index, name_offset);
        const title_offset = name_offset + @sizeOf(u16) + doc_name.len;
        const title = readStr(self.index, title_offset);
        return .{ doc_name, title };
    }

    pub fn snippet(self: *const Self, doc_id: u32) [2]u32 {
        const stride = doc_id * @sizeOf(u32);
        const start = read32(self.index, self.header.snippets_offset + stride);
        const end = read32(self.index, self.header.snippets_offset + stride + @sizeOf(u32));
        return [2]u32{ start, end };
    }

    fn postings_chunk(self: *const Self, offset: u32, results: []Result, neg: bool) void {
        const ids_len = read32(self.index, offset);
        const score = self.index[offset + @sizeOf(u32)];
        const ids = offset + @sizeOf(u32) + @sizeOf(u8);

        var i: u32 = 0;
        var last_id: u32 = 0;
        while (i < ids_len) {
            var doc_id: u32 = 0;
            i += vbyte.read(self.index[ids + i ..], &doc_id);
            doc_id += last_id;
            if (!neg) {
                results[doc_id].score += score;
            } else {
                results[doc_id].score = 0;
            }
            last_id = doc_id;
        }
    }

    fn postings(self: *const Self, offset: u32, results: []Result, neg: bool) void {
        var chunk_offset = offset;
        var chunk_len = read32(self.index, chunk_offset);
        var chunk_score: u8 = 255;

        while (chunk_len != 0) {
            chunk_score = self.index[chunk_offset + @sizeOf(u32)];
            self.postings_chunk(chunk_offset, results, neg);
            chunk_offset += @sizeOf(u32) + @sizeOf(u8) + chunk_len;
            chunk_len = read32(self.index, chunk_offset);
        }
    }

    pub fn find(self: *const Self, key: []const u8, results: []Result, neg: bool) void {
        const cap = read32(self.index, self.header.dictionary_offset);
        const table = self.header.dictionary_offset + @sizeOf(u32);

        var i = hash(key, cap);
        while (true) {
            const postings_offset = table + i * @sizeOf(u32);

            const term_store = read32(self.index, postings_offset);
            if (term_store == 0)
                return;
            const term = readStr(self.index, term_store);
            if (std.mem.eql(u8, term, key))
                return self.postings(@truncate(term_store + @sizeOf(u16) + term.len), results, neg);

            i = i + 1 & (cap - 1);
        }
    }
};
