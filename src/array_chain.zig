// ARRAY_CHAIN.ZIG
// ---------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

pub fn ArrayChain(comptime T: type) type {
    return struct {
        const Self = @This();

        const Chunk = struct {
            items: []T,
            capacity: usize,
            next: ?*Chunk,
        };

        first: ?*Chunk = null,
        last: ?*Chunk = null,
        next_chunk_size: usize = 64,

        fn ensureChunk(self: *Self, allocator: std.mem.Allocator) !void {
            var chunk = self.last;
            if (chunk == null) {
                chunk = try allocator.create(Chunk);
                chunk.?.items = try allocator.alloc(T, self.next_chunk_size);
                chunk.?.items.len = 0;
                chunk.?.capacity = self.next_chunk_size;
                chunk.?.next = null;

                self.first = chunk;
                self.last = chunk;
                self.next_chunk_size *= 2;
            }
        }

        // TODO what if additional_count exceeds next_chunk_size?
        pub fn ensureUnusedCapacity(self: *Self, allocator: std.mem.Allocator, additional_count: usize) !void {
            try self.ensureChunk(allocator);
            var chunk = self.last.?;
            if (chunk.items.len + additional_count >= chunk.capacity) {
                var nextChunk = try allocator.create(Chunk);
                nextChunk.items = try allocator.alloc(T, self.next_chunk_size);
                nextChunk.items.len = 0;
                nextChunk.capacity = self.next_chunk_size;
                nextChunk.next = null;

                chunk.next = nextChunk;
                self.last = nextChunk;
                self.next_chunk_size *= 2;
            }
        }

        pub fn append(self: *Self, allocator: std.mem.Allocator, item: T) !void {
            try self.ensureUnusedCapacity(allocator, 1);
            var chunk = self.last.?;
            chunk.items.len += 1;
            chunk.items[chunk.items.len - 1] = item;
        }
    };
}
