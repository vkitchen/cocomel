//	INDEX_CLI.ZIG
//	-------------
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

    var buffer: [100]u8 = undefined;

    const snippets_file = try std.fs.cwd().createFile(config.files.snippets, .{});
    defer snippets_file.close();

    var snippets_buf = std.io.bufferedWriter(snippets_file.writer());

    var indexer = try Indexer.init(allocator, snippets_buf.writer());

    for (args[1..]) |filename| {
        if (std.mem.endsWith(u8, filename, ".xml")) {
            var toker = try WsjTokenizer.init(allocator, &indexer, filename);
            try toker.tokenize();
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
                    var docno = try str.dup(allocator, t.token);
                    try indexer.addDocId(docno);
                    continue;
                }
                try indexer.addTerm(t.token);
            }
        } else {
            std.debug.print("ERROR: Unknown filetype for '{s}'\n", .{filename});
            std.process.exit(1);
        }
    }

    const index_file = try std.fs.cwd().createFile(config.files.index, .{});
    defer index_file.close();

    var index_buf = std.io.bufferedWriter(index_file.writer());

    try indexer.write(index_buf.writer());

    try snippets_buf.flush();
    try index_buf.flush();
}
