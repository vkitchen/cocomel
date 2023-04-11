//	SEARCH.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const hashTable = @import("hash_table.zig");

fn name(index: []const u8, offset: u32, doc_id: u32) []const u8 {
    const docs_start = offset + @sizeOf(u32);

    const stride = doc_id * @sizeOf(u32);
    const name_offset = std.mem.bytesToValue(u32, index[docs_start + stride .. docs_start + stride + @sizeOf(u32)][0..4]);
    const name_length = std.mem.bytesToValue(u32, index[name_offset .. name_offset + @sizeOf(u32)][0..4]);
    const name_start = name_offset + @sizeOf(u32);
    return index[name_start .. name_start + name_length];
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

    const docs_count = std.mem.bytesToValue(u32, index[docs_offset .. docs_offset + 4][0..4]);
    std.debug.print("No. docs {d}\n", .{docs_count});

    var results = try allocator.alloc(hashTable.Result, docs_count);
    var i: u32 = 0;
    while (i < docs_count) : (i += 1) {
        results[i].doc_id = i;
        results[i].score = 0;
    }

    std.debug.print("{s}", .{"Query> "});
    const stdin = std.io.getStdIn().reader();

    var buf: [10]u8 = undefined;
    var input = try stdin.readUntilDelimiterOrEof(&buf, '\n');

    std.debug.print("Searching {s}\n", .{input.?});
    hashTable.find(index, hash_offset, input.?, results);
    std.debug.print("Results: {s}\n", .{""});
    i = 0;
    while (i < docs_count) : (i += 1) {
        if (results[i].score > 0) {
            std.debug.print("Result: {s}. Score: {d}\n", .{ name(index, docs_offset, results[i].doc_id), results[i].score });
        }
    }
}
