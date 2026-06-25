// INDEX.ZIG
// ---------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Wyhash = std.hash.Wyhash;

const config = @import("config.zig");
const snippets = @import("snippets.zig");
const vbyte = @import("compress_int_vbyte.zig");
const TopK = @import("top_k_insert.zig").TopKInsert;
const Stemmer = @import("stem.zig").Stemmer;

const c = @import("c");

pub const version = 1;

pub const ImpactType = if (((1 << config.quantise_bits) - 1) > std.math.maxInt(u8)) u16 else u8;

pub const Result = struct {
    docid: u32,
    score: u16,
};

pub const VocabTuple = extern struct {
    hash: config.FileOffsetType,
    term: config.FileOffsetType,
};

pub const SegmentTuple = struct {
    segment: u64,
    header: u64,
};

// Helpers for unaligned reads

fn read16(buf: []const u8, offset: u64) u16 {
    return std.mem.bytesToValue(u16, buf[offset .. offset + @sizeOf(u16)][0..2]);
}

fn read32(buf: []const u8, offset: u64) u32 {
    return std.mem.bytesToValue(u32, buf[offset .. offset + @sizeOf(u32)][0..4]);
}

fn read64(buf: []const u8, offset: u64) u64 {
    return std.mem.bytesToValue(u64, buf[offset .. offset + @sizeOf(u64)][0..8]);
}

fn readStr(buf: []const u8, offset: u64) []const u8 {
    const len = read16(buf, offset);
    const start = offset + @sizeOf(u16);
    return buf[start .. start + len];
}

fn readArray(buf: []const u8, offset: u64) []const config.FileOffsetType {
    const len = read64(buf, offset); // Always a u64
    const start = offset + @sizeOf(u64);
    return @alignCast(std.mem.bytesAsSlice(config.FileOffsetType, buf[start .. start + len * @sizeOf(config.FileOffsetType)]));
}

fn readVocabArray(buf: []const u8, offset: u64) []const VocabTuple {
    const len = read64(buf, offset);
    const start = offset + @sizeOf(u64);
    return @alignCast(std.mem.bytesAsSlice(VocabTuple, buf[start .. start + len * @sizeOf(VocabTuple)]));
}

// Index contains "sub-files"
// Offsets in the structures are relative to the "sub-files"
// Ordering of the index is not guaranteed
// Though the header is always at the end
pub const Header = extern struct {
    // precomputed values
    max_doc_length: u64,

    // "sub-files"
    snippets_store: [2]u64,
    blocks_store: [2]u64,
    postings_store: [2]u64,
    docs_store: [2]u64,

    // structures
    snippets: u64,
    vocab: u64,
    docs: u64,

    // config
    stemmer: Stemmer.Alg,
    _reserved: [5]u8 = .{0} ** 5,
    version: u16,
};

pub const Index = struct {
    const Self = @This();

    header: *const Header,

    // "sub-files"
    snippets_store: []const u8,
    blocks_store: []const u128,
    postings_store: []const u8,
    docs_store: []const u8,

    // structures
    snippets: []const config.FileOffsetType,
    vocab: []const VocabTuple,
    docs: []const config.FileOffsetType,

    pub fn init(index: []align(16) const u8) !Self {
        const header: *const Header = @alignCast(std.mem.bytesAsValue(Header, index[index.len - @sizeOf(Header) ..]));

        if (header.version != version) {
            std.debug.print("Incorrect index version\n", .{});
            std.process.exit(1);
        }

        return .{
            .header = header,

            // "sub-files"
            .snippets_store = index[header.snippets_store[0]..header.snippets_store[1]],
            .blocks_store = @ptrCast(@alignCast(index[header.blocks_store[0]..header.blocks_store[1]])),
            .postings_store = index[header.postings_store[0]..header.postings_store[1]],
            .docs_store = index[header.docs_store[0]..header.docs_store[1]],

            // structures
            .snippets = if (header.snippets != 0) readArray(index, header.snippets) else &.{},
            .vocab = readVocabArray(index, header.vocab),
            .docs = readArray(index, header.docs),
        };
    }

    pub fn hasSnippets(self: *const Self) bool {
        return self.header.snippets != 0;
    }

    // [   u16   ][ []u8 ][   u16   ][ []u8 ]
    // [ strlen  ][ str  ][ strlen  ][ str  ]
    pub fn name(self: *const Self, doc_id: u32) [2][]const u8 {
        const name_offset = self.docs[doc_id];
        const doc_name = readStr(self.docs_store, name_offset);
        const title_offset = name_offset + @sizeOf(u16) + doc_name.len;
        const title = readStr(self.docs_store, title_offset);
        return .{ doc_name, title };
    }

    pub fn snippet(self: *const Self, doc_id: u32) [2]u64 {
        return [2]u64{ self.snippets[doc_id], self.snippets[doc_id + 1] };
    }

    pub fn segmentScore(self: *const Self, offset: u64) ImpactType {
        return if (ImpactType == u16) read16(self.postings_store, offset) else self.postings_store[offset];
    }

    pub fn decompressSegment(self: *const Self, segment: *SegmentTuple, buf: []u32) u64 {
        var doc_count: u32 = 0;
        const selectors = segment.header + @sizeOf(ImpactType) + vbyte.read(self.postings_store[segment.header + @sizeOf(ImpactType) ..], &doc_count);

        const block = segment.segment / 16;
        segment.segment += c.compress_int_unpack_d1(@ptrCast(buf.ptr), @ptrCast(self.blocks_store[block..].ptr), self.postings_store[selectors..].ptr, doc_count);
        segment.header = selectors + doc_count / 128;

        return doc_count;
    }

    // Returns start of segment header and start of segments
    pub fn find(self: *const Self, key: []const u8) SegmentTuple {
        var i: u64 = Wyhash.hash(0, key) & self.vocab.len - 1;
        const hash2: u32 = @truncate(Wyhash.hash(42, key) & std.math.maxInt(u32));
        while (true) {
            if (self.vocab[i].term == 0)
                return .{ .segment = 0, .header = 0 };
            if (self.vocab[i].hash != hash2) {
                i = i + 1 & self.vocab.len - 1;
                continue;
            }
            const term = readStr(self.postings_store, self.vocab[i].term);
            if (std.mem.eql(u8, term, key)) {
                var postings_start = self.vocab[i].term + @sizeOf(u16) + term.len;

                var blocks_start: u32 = 0;
                postings_start += vbyte.read(self.postings_store[postings_start..], &blocks_start);
                return .{ .segment = @as(u64, blocks_start) * 16, .header = postings_start };
            }

            i = i + 1 & self.vocab.len - 1;
        }
    }
};
