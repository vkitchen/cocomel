//	PROG_INDEX.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const HtmlTokenizer = @import("tokenizer_html_file.zig").HtmlFileTokenizer;
const WsjTokenizer = @import("tokenizer_wsj.zig").WsjTokenizer;
const TarTokenizer = @import("tokenizer_tar.zig").TarTokenizer;
const Token = @import("tokenizer.zig").Token;
const Dictionary = @import("dictionary.zig").Dictionary;
const Indexer = @import("indexer.zig").Indexer;
const stem = @import("stem.zig").stem;
const serialise = @import("serialise_ccml.zig");
const config = @import("config.zig");
const str = @import("str.zig");

const usage =
    \\
    \\Usage: index [file ...]
    \\
;

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

    var indexer = try Indexer.init(allocator);

    for (args[1..]) |filename| {
        if (std.mem.endsWith(u8, filename, ".xml")) {
            var doc = try std.fs.cwd().openFile(filename, .{});
            defer doc.close();

            const tokerType = WsjTokenizer(@TypeOf(doc));

            var toker = try tokerType.init(&indexer, doc);
            try toker.tokenize();
        } else if (std.mem.endsWith(u8, filename, ".tar.gz")) {
            var doc = try std.fs.cwd().openFile(filename, .{});
            defer doc.close();

            var buf = std.io.bufferedReader(doc.reader());
            var gzip_stream = try std.compress.gzip.decompress(allocator, buf.reader());
            defer gzip_stream.deinit();

            const tokerType = TarTokenizer(@TypeOf(gzip_stream));
            var toker = tokerType.init(&indexer, gzip_stream);
            try toker.tokenize();
        } else {
            // Assume directory
            var dir = try std.fs.cwd().openDir(filename, .{ .iterate = true });
            defer dir.close();

            var walker = try dir.walk(allocator);

            var buffer: [1000]u8 = undefined;
            var decoder = std.base64.Base64Decoder.init(std.fs.base64_alphabet, '=');

            while (try walker.next()) |handle| {
                if (!std.mem.endsWith(u8, handle.path, ".html"))
                    continue;
                const raw_address = handle.path[0 .. handle.path.len - 5];
                const result_len = try decoder.calcSizeForSlice(raw_address);
                try decoder.decode(&buffer, raw_address);
                const address = buffer[0..result_len];

                try indexer.addDocId(address);

                var doc = try handle.dir.openFile(handle.path, .{});
                defer doc.close();

                const tokerType = HtmlTokenizer(@TypeOf(doc));

                var toker = try tokerType.init(&indexer, doc);
                try toker.tokenize();
            }
        }
    }

    try indexer.write();
}
