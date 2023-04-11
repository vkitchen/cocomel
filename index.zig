//	INDEX.ZIG
//	---------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const HashTable = @import("hash_table.zig").HashTable;

const usage =
    \\
    \\Usage: index [file ...]
    \\
;

const file_format = "cocomel v1\n";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("{s}", .{usage});
        return;
    }

    const doc = try file.slurp(allocator, args[1]);

    var tok = Tokenizer.init(doc);

    var docs = std.ArrayList([]const u8).init(allocator);
    var dictionary = try HashTable.init(allocator);

    while (true) {
        const t = tok.next();
        if (t.type == Token.Type.eof) break;
        if (t.type == Token.Type.docno) {
            if (docs.items.len > 0 and docs.items.len % 10000 == 0)
                std.debug.print("{d} Documents\n", .{docs.items.len});
            try docs.append(t.token);
        }
        if (docs.items.len == 0)
            continue;
        try dictionary.insert(allocator, t.token, @truncate(u32, docs.items.len - 1));
    }

    // Write index
    std.debug.print("{s}\n", .{"Writing index..."});

    const index_file = try std.fs.cwd().createFile("index.dat", .{});
    defer index_file.close();

    var buf = std.io.bufferedWriter(index_file.writer());
    var out = buf.writer();

    // Header
    try out.writeAll(file_format);
    var bytes_written: u32 = file_format.len;

    // Document ID strings
    var offsets = std.ArrayList(u32).init(allocator); // TODO we don't want this intermediate
    for (docs.items) |d| {
        try out.writeIntNative(u32, @truncate(u32, d.len));
        try out.writeAll(d);
        try offsets.append(bytes_written);
        bytes_written += @sizeOf(u32);
        bytes_written += @truncate(u32, d.len);
    }

    // Document IDs array
    const docs_offset = bytes_written;
    try out.writeIntNative(u32, @truncate(u32, offsets.items.len));
    bytes_written += @sizeOf(u32);
    for (offsets.items) |o| {
        try out.writeIntNative(u32, o);
        bytes_written += @sizeOf(u32);
    }

    // Dictionary
    const dictionary_offset = try dictionary.write(out, &bytes_written);

    // Metadata
    try out.writeIntNative(u32, docs_offset);
    try out.writeIntNative(u32, dictionary_offset);
    bytes_written += 2 * @sizeOf(u32);

    try buf.flush();

    std.debug.print("Wrote index of size {d}\n", .{bytes_written});
}
