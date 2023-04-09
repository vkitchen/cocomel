//	SEARCH.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const hashTable = @import("hash_table.zig");

fn ten_ids(index: []const u8, offset: u32, ids: [11]u32) [10][]const u8 {
    var out: [10][]const u8 = undefined;

    const docs_length = std.mem.bytesToValue(u32, index[offset .. offset + 4][0..4]);
    const docs_start = offset + @sizeOf(u32);

    std.debug.print("No. docs {d}\n", .{docs_length});

    var i: u32 = 1;
    while (i < ids[0] + 1) : (i += 1) {
        const stride = ids[i] * @sizeOf(u32);
        const name_offset = std.mem.bytesToValue(u32, index[docs_start + stride .. docs_start + stride + @sizeOf(u32)][0..4]);
        const name_length = std.mem.bytesToValue(u32, index[name_offset .. name_offset + @sizeOf(u32)][0..4]);
        const name_start = name_offset + @sizeOf(u32);
        const name = index[name_start .. name_start + name_length];
        out[i - 1] = name;
    }

    return out;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    std.debug.print("{s}\n", .{"Reading index..."});
    const index = try file.slurp(allocator, "index.dat");
    std.debug.print("Index size {d}\n", .{index.len});

    const docs_offset = std.mem.bytesToValue(u32, index[index.len - 8 .. index.len - 4][0..4]);
    const hash_offset = std.mem.bytesToValue(u32, index[index.len - 4 .. index.len][0..4]);

    std.debug.print("{s}", .{"Query> "});
    const stdin = std.io.getStdIn().reader();

    var buf: [10]u8 = undefined;
    var input = try stdin.readUntilDelimiterOrEof(&buf, '\n');

    std.debug.print("Searching {s}\n", .{input.?});
    var result = hashTable.find(index, hash_offset, input.?);
    if (result != null) {
        std.debug.print("Result count {d}\n", .{result.?[0]});
        var names = ten_ids(index, docs_offset, result.?);
        var i: u32 = 1;
        while (i < result.?[0] + 1) : (i += 1) {
            std.debug.print("Result {d}: {s}\n", .{ i, names[i - 1] });
        }
    } else {
        std.debug.print("{s}\n", .{"No results..."});
    }
}
