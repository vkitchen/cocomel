//	SEARCH.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const hashTable = @import("hash_table.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    std.debug.print("{s}\n", .{"Reading index..."});
    const index = try file.slurp(allocator, "index.dat");
    std.debug.print("Index size {d}\n", .{index.len});

    // const docs_offset = std.mem.bytesToValue(u32, index[index.len - 8 .. index.len - 4][0..4]);
    const hash_offset = std.mem.bytesToValue(u32, index[index.len - 4 .. index.len][0..4]);

    std.debug.print("{s}", .{"Query> "});
    const stdin = std.io.getStdIn().reader();

    var buf: [10]u8 = undefined;
    var input = try stdin.readUntilDelimiterOrEof(&buf, '\n');

    std.debug.print("Searching {s}\n", .{input.?});
    var result = hashTable.find(index, hash_offset, input.?);
    if (result != null) {
        std.debug.print("Result count {d}\n", .{result.?[0]});
        var i: u32 = 1;
        while (i < result.?[0]) : (i += 1) {
            std.debug.print("Result {d}: {d}\n", .{ i, result.?[i] });
        }
    } else {
        std.debug.print("{s}\n", .{"No results..."});
    }
}
