// INDEX.ZIG
// ---------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Wyhash = std.hash.Wyhash;

const config = @import("config.zig");
const compress = @import("compress_int.zig");
const snippets = @import("snippets.zig");
const vbyte = @import("compress_int_vbyte.zig");
const TopK = @import("top_k_tournament.zig").TopKTournament;
const Stemmer = @import("stem.zig").Stemmer;

const c = @import("c");

pub const version = 1;

pub const ImpactType = if (((1 << config.quantise_bits) - 1) > std.math.maxInt(u8)) u16 else u8;

pub const Result = struct {
    docid: u32,
    score: u16,
};

pub const VocabTuple = extern struct {
    hash: u64,
    term: u64,
};

pub const SegmentHeader = struct {
    impact: ImpactType,
    len: u32,
};

pub const PostingsHeader = struct {
    len: usize, // total docs
    segments: []SegmentHeader,
    blocks: u64,
    postings: u64,
};

var decompression_buffer: [128]u32 align(16) = undefined;

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
    compressor: compress.Compressor,
    stemmer: Stemmer.Alg,
    doc_fields: u8,
    _reserved: [3]u8 = .{0} ** 3,
    version: u16,
};

pub const Index = struct {
    const Self = @This();

    header: *const Header,
    allocator: std.heap.FixedBufferAllocator,

    // "sub-files"
    snippets_store: []const u8,
    blocks_store: []const u128,
    postings_store: []const u8,
    docs_store: []const u8,

    // structures
    snippets: []const config.FileOffsetType,
    vocab: []const VocabTuple,
    docs: []const config.FileOffsetType,

    pub fn init(index: []align(16) const u8, postings_buf: []u8) !Self {
        const header: *const Header = @alignCast(std.mem.bytesAsValue(Header, index[index.len - @sizeOf(Header) ..]));

        if (header.version != version) {
            std.debug.print("Incorrect index version\n", .{});
            std.process.exit(1);
        }

        return .{
            .header = header,
            .allocator = std.heap.FixedBufferAllocator.init(postings_buf),

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

    pub fn reset(self: *Self) void {
        self.allocator.reset();
    }

    pub fn hasSnippets(self: *const Self) bool {
        return self.header.snippets != 0;
    }

    // [   u16   ][ []u8 ][   u16   ][ []u8 ]
    // [ strlen  ][ str  ][ strlen  ][ str  ]
    pub fn name(self: *const Self, doc_id: u32) [2][]const u8 {
        const name_offset = self.docs[doc_id];
        const doc_name = readStr(self.docs_store, name_offset);
        var title: []const u8 = "";
        if (self.header.doc_fields > 1) {
            const title_offset = name_offset + @sizeOf(u16) + doc_name.len;
            title = readStr(self.docs_store, title_offset);
        }
        return .{ doc_name, title };
    }

    pub fn snippet(self: *const Self, doc_id: u32) [2]u64 {
        return [2]u64{ self.snippets[doc_id], self.snippets[doc_id + 1] };
    }

    inline fn decompressBlock(self: *const Self, blocks: *u64, postings: *u64, len: u32, last_id: u32) []u32 {
        const doc_count = @min(128, len);
        const res = compress.unpack_block_d1(self.header.compressor, self.blocks_store[blocks.*..], self.postings_store[postings.*..], &decompression_buffer, doc_count, last_id);
        blocks.* += res.blocks;
        postings.* += res.bytes;
        return decompression_buffer[0..doc_count];
    }

    pub fn readPostings(self: *const Self, header: *const PostingsHeader, results: []Result) []Result {
        var out = results;
        out.len = 0;

        var blocks = header.blocks;
        var postings = header.postings;

        for (0..header.segments.len) |i| {
            var segment = header.segments[i];
            var last_id: u32 = 0;

            while (segment.len > 0) {
                const docids = self.decompressBlock(&blocks, &postings, segment.len, last_id);
                for (docids) |doc| {
                    out.len += 1;
                    out[out.len - 1] = .{ .docid = doc, .score = segment.impact };

                    if (out.len == results.len)
                        return out;
                }
                last_id = decompression_buffer[docids.len - 1];
                segment.len -= @truncate(docids.len);
            }
        }

        return out;
    }

    pub fn accumulatePostings(self: *const Self, header: *const PostingsHeader, topk: *TopK, accumulators: []config.AccumulatorType) void {
        var blocks = header.blocks;
        var postings = header.postings;

        for (0..header.segments.len) |i| {
            var segment = header.segments[i];
            var last_id: u32 = 0;

            while (segment.len > 0) {
                const docids = self.decompressBlock(&blocks, &postings, segment.len, last_id);
                for (docids) |doc| {
                    const saved = accumulators[doc];
                    accumulators[doc] += segment.impact;
                    topk.insert(doc, accumulators[doc], saved);
                }
                last_id = decompression_buffer[docids.len - 1];
                segment.len -= @truncate(docids.len);
            }
        }
    }

    fn readImpact(self: *const Self, offset: u64) ImpactType {
        return if (ImpactType == u16) read16(self.postings_store, offset) else self.postings_store[offset];
    }

    fn readPostingsHeader(self: *Self, offset: u64) !PostingsHeader {
        var index = offset;
        const num_segments = self.readImpact(index);
        index += @sizeOf(ImpactType);
        var total_docs: usize = 0;
        var segments = try self.allocator.allocator().alloc(SegmentHeader, num_segments);
        for (0..num_segments) |i| {
            const impact = self.readImpact(index);
            index += @sizeOf(ImpactType);
            var num_docs: u32 = undefined;
            index += vbyte.read(self.postings_store[index..], &num_docs);
            segments[i] = .{ .impact = impact, .len = num_docs };
            total_docs += num_docs;
        }
        var blocks_start: u32 = undefined;
        index += vbyte.read(self.postings_store[index..], &blocks_start);
        return .{ .len = total_docs, .segments = segments, .blocks = blocks_start, .postings = index };
    }

    // Returns start of segment header and start of segments
    pub fn find(self: *Self, key: []const u8) !?PostingsHeader {
        var i: u64 = Wyhash.hash(0, key) & self.vocab.len - 1;
        const hash2 = Wyhash.hash(42, key);
        while (true) {
            if (self.vocab[i].term == 0)
                return null;
            if (self.vocab[i].hash != hash2) {
                i = i + 1 & self.vocab.len - 1;
                continue;
            }
            const term = readStr(self.postings_store, self.vocab[i].term);
            if (std.mem.eql(u8, term, key)) {
                const postings_start = self.vocab[i].term + @sizeOf(u16) + term.len;
                return try self.readPostingsHeader(postings_start);
            }

            i = i + 1 & self.vocab.len - 1;
        }
    }
};
