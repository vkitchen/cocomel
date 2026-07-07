// HASH_MAP.ZIG
// ------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Wyhash = std.hash.Wyhash;

pub fn HashMap(comptime T: type) type {
    const Pair = struct {
        key: ?[]u8,
        val: ?T,
    };

    return struct {
        const Self = @This();

        cap: u32,
        len: u32 = 0,
        store: []Pair, // TODO can the optimizer nullify the struct?

        pub fn init(allocator: std.mem.Allocator) !Self {
            return initCapacity(allocator, 1 << 19);
        }

        pub fn initCapacity(allocator: std.mem.Allocator, cap: u32) !Self {
            const top_bit: u5 = @truncate(@bitSizeOf(@TypeOf(cap)) - 1 - @clz(cap));
            const fixed_cap = if (cap & (@as(u32, 1) << top_bit) == cap) cap else @as(u32, 1) << (top_bit + 1);

            const store = try allocator.alloc(Pair, fixed_cap);
            @memset(store, .{ .key = null, .val = null });
            return .{ .cap = fixed_cap, .store = store };
        }

        fn expand(self: *Self, allocator: std.mem.Allocator) !void {
            const new_cap = self.cap << 1;
            var new_store = try allocator.alloc(Pair, new_cap);
            @memset(new_store, .{ .key = null, .val = null });

            for (self.store) |p| {
                if (p.key != null) {
                    var i = Wyhash.hash(0, p.key.?) & self.cap - 1;
                    while (new_store[i].key != null)
                        i = i + 1 & new_cap - 1;

                    new_store[i] = p;
                }
            }

            allocator.free(self.store);
            self.cap = new_cap;
            self.store = new_store;
        }

        pub fn emplace(self: *Self, allocator: std.mem.Allocator, key: []const u8) !*?T {
            if (self.len > self.cap / 2)
                try self.expand(allocator);

            var i = Wyhash.hash(0, key) & self.cap - 1;
            while (self.store[i].key != null) {
                if (std.mem.eql(u8, self.store[i].key.?, key))
                    return &self.store[i].val;

                i = i + 1 & self.cap - 1;
            }

            self.store[i].key = try allocator.dupe(u8, key);
            self.len += 1;

            return &self.store[i].val;
        }
    };
}
