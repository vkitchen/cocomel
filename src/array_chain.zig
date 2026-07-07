// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");

const initial_capacity = 128;

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

        pub fn initCapacity(allocator: std.mem.Allocator, cap: usize) !Self {
            const chunk = try allocator.create(Chunk);
            chunk.items = try allocator.alloc(T, cap);
            chunk.items.len = 0;
            chunk.capacity = cap;
            chunk.next = null;

            var self: Self = .{};
            self.first = chunk;
            self.last = chunk;

            return self;
        }

        fn ensureChunk(self: *Self, allocator: std.mem.Allocator) !void {
            var chunk = self.last;
            if (chunk == null) {
                chunk = try allocator.create(Chunk);
                chunk.?.items = try allocator.alloc(T, initial_capacity / @sizeOf(T));
                chunk.?.items.len = 0;
                chunk.?.capacity = initial_capacity;
                chunk.?.next = null;

                self.first = chunk;
                self.last = chunk;
            }
        }

        // TODO what if additional_count exceeds next_chunk_size?
        pub fn ensureUnusedCapacity(self: *Self, allocator: std.mem.Allocator, additional_count: usize) !void {
            try self.ensureChunk(allocator);
            var chunk = self.last.?;
            if (chunk.items.len + additional_count >= chunk.capacity) {
                var nextChunk = try allocator.create(Chunk);
                nextChunk.items = try allocator.alloc(T, chunk.capacity * 2);
                nextChunk.items.len = 0;
                nextChunk.capacity = chunk.capacity * 2;
                nextChunk.next = null;

                chunk.next = nextChunk;
                self.last = nextChunk;
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
