//	PROG_INDEX.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
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
            var gzip_stream = try std.compress.gzip.gzipStream(allocator, buf.reader());
            defer gzip_stream.deinit();

            const tokerType = TarTokenizer(@TypeOf(gzip_stream));
            var toker = tokerType.init(&indexer, gzip_stream);
            try toker.tokenize();
        } else {
            std.debug.print("ERROR: Unknown filetype for '{s}'\n", .{filename});
            std.process.exit(1);
        }
    }

    try indexer.write();
}
