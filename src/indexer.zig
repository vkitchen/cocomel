//	INDEXER.ZIG
//	-----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const TarTokenizer = @import("tokenizer.zig").TarTokenizer;
const Token = @import("tokenizer.zig").Token;
const HashTable = @import("dictionary.zig").HashTable;

const usage =
    \\
    \\Usage: index [file ...]
    \\
;

const file_format = "cocomel v1\n";

const Doc = struct {
    name: []u8,
    len: u32 = 0,
};

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

    var docs = std.ArrayList(Doc).init(allocator);
    var dictionary = try HashTable.init(allocator);

    var buffer: [100]u8 = undefined;

    const snippets_file = try std.fs.cwd().createFile("snippets.dat", .{});
    defer snippets_file.close();

    var snippets_buf = std.io.bufferedWriter(snippets_file.writer());
    var snippets_writer = snippets_buf.writer();
    var snippets_written: u32 = 0;
    var snippets_indices = std.ArrayList(u32).init(allocator);

    for (args[1..]) |filename| {
        if (std.mem.endsWith(u8, filename, ".xml")) {
            const doc = try file.slurp(allocator, filename);
            var tok = Tokenizer.init(doc);
            while (true) {
                const t = tok.next(&buffer);
                if (t.type == Token.Type.eof) break;
                if (t.type == Token.Type.docno) {
                    if (docs.items.len > 0 and docs.items.len % 10000 == 0)
                        std.debug.print("{d} Documents\n", .{docs.items.len});
                    try docs.append(.{ .name = t.token });
                    try snippets_indices.append(snippets_written);
                    continue;
                }
                if (docs.items.len == 0)
                    continue;
                try dictionary.insert(allocator, t.token, @truncate(u32, docs.items.len - 1));
                docs.items[docs.items.len - 1].len += 1;
                try snippets_writer.writeAll(t.token);
                try snippets_writer.writeByte(' ');
                snippets_written += @truncate(u32, t.token.len + 1);
            }
        } else if (std.mem.endsWith(u8, filename, ".tar.gz")) {
            var doc = try std.fs.cwd().openFile(filename, .{});
            defer doc.close();

            var buf = std.io.bufferedReader(doc.reader());
            var gzip_stream = try std.compress.gzip.gzipStream(allocator, buf.reader());
            defer gzip_stream.deinit();

            const tokType = TarTokenizer(@TypeOf(gzip_stream));
            var tok = tokType.init(gzip_stream);
            while (true) {
                const t = try tok.next(&buffer);
                if (t.type == Token.Type.eof) break;
                if (t.type == Token.Type.docno) {
                    if (docs.items.len > 0 and docs.items.len % 1000 == 0)
                        std.debug.print("{d} Documents\n", .{docs.items.len});
                    var docno = try allocator.alloc(u8, t.token.len);
                    std.mem.copy(u8, docno, t.token);
                    try docs.append(.{ .name = docno });
                    try snippets_indices.append(snippets_written);
                    continue;
                }
                if (docs.items.len == 0)
                    continue;
                try dictionary.insert(allocator, t.token, @truncate(u32, docs.items.len - 1));
                docs.items[docs.items.len - 1].len += 1;
                try snippets_writer.writeAll(t.token);
                try snippets_writer.writeByte(' ');
                snippets_written += @truncate(u32, t.token.len + 1);
            }
        } else {
            std.debug.print("ERROR: Unknown filetype for '{s}'\n", .{filename});
            std.process.exit(1);
        }
    }

    try snippets_indices.append(snippets_written);
    try snippets_buf.flush();

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
    for (docs.items) |d, i| {
        try out.writeIntNative(u32, d.len);
        try out.writeIntNative(u32, @truncate(u32, d.name.len));
        try out.writeAll(d.name);
        docs.items[i].name.ptr = @intToPtr([*]u8, bytes_written);
        bytes_written += 2 * @sizeOf(u32);
        bytes_written += @truncate(u32, d.name.len);
    }

    // Document IDs array
    const docs_offset = bytes_written;
    try out.writeIntNative(u32, @truncate(u32, docs.items.len));
    bytes_written += @sizeOf(u32);
    for (docs.items) |d| {
        try out.writeIntNative(u32, @truncate(u32, @ptrToInt(d.name.ptr)));
        bytes_written += @sizeOf(u32);
    }

    // Dictionary
    const dictionary_offset = try dictionary.write(out, &bytes_written);

    // Snippets
    const snippets_offset = bytes_written;
    try out.writeIntNative(u32, @truncate(u32, snippets_indices.items.len));
    for (snippets_indices.items) |s| {
        try out.writeIntNative(u32, s);
        bytes_written += @sizeOf(u32);
    }

    // Metadata
    try out.writeIntNative(u32, snippets_offset);
    try out.writeIntNative(u32, docs_offset);
    try out.writeIntNative(u32, dictionary_offset);
    bytes_written += 3 * @sizeOf(u32);

    try buf.flush();

    std.debug.print("Wrote index of size {d}\n", .{bytes_written});
}
