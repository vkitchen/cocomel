// PROG_INDEX.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const clap = @import("clap");

const HtmlTokenizer = @import("tokenizer_html.zig").HtmlTokenizer;
const WsjTokenizer = @import("tokenizer_wsj.zig").WsjTokenizer;
const TarTokenizer = @import("tokenizer_tar.zig").TarTokenizer;
const Indexer = @import("indexer.zig").Indexer;

var reader_buf: [4096]u8 = undefined;

pub fn main(init: std.process.Init) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\--snippets             Whether to generate a snippet index for the input.
        \\--bigrams              Whether to include bigrams in index.
        \\--wsj                  Whether the files to index are in trec wsj format.
        \\<file>...
        \\
    );

    const cli_parsers = comptime .{
        .file = clap.parsers.string,
    };

    var res = try clap.parse(clap.Help, &params, cli_parsers, init.minimal.args, .{ .allocator = init.arena.allocator() });
    defer res.deinit();

    var indexer = try Indexer.init(init.io, init.arena.allocator(), res.args.snippets != 0, res.args.bigrams != 0);

    if (res.args.help != 0)
        return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});
    if (res.args.wsj != 0) {
        for (res.positionals[0]) |filename| {
            if (std.mem.endsWith(u8, filename, ".xml")) {
                var doc = try std.Io.Dir.cwd().openFile(init.io, filename, .{});
                defer doc.close(init.io);

                var reader = doc.reader(init.io, &reader_buf);

                var toker = try WsjTokenizer.init(&indexer, &reader.interface);
                try toker.tokenize(init.arena.allocator());
            } else {
                std.debug.print("WARNING: Don't know how to index '{s}'\n", .{filename});
            }
        }

        try indexer.write(init.io, init.arena.allocator());
        return;
    } else {
        for (res.positionals[0]) |filename| {
            if (std.mem.endsWith(u8, filename, ".html")) {
                var doc = try std.Io.Dir.cwd().openFile(init.io, filename, .{});
                defer doc.close(init.io);

                var reader = doc.reader(init.io, &reader_buf);

                try indexer.addDocId(init.arena.allocator(), filename);

                const stat = try doc.stat(init.io);
                const file_size = stat.size;

                var toker = HtmlTokenizer.init(&indexer);

                try toker.tokenize(&reader.interface, file_size);
            } else if (std.mem.endsWith(u8, filename, ".tar.gz")) {
                var doc = try std.Io.Dir.cwd().openFile(init.io, filename, .{});
                defer doc.close(init.io);

                var reader = doc.reader(init.io, &reader_buf);

                var gzip_buf: [std.compress.flate.max_window_len]u8 = undefined;
                var gzip_stream = std.compress.flate.Decompress.init(&reader.interface, .gzip, &gzip_buf);

                var toker = TarTokenizer.init(&indexer, &gzip_stream.reader);
                try toker.tokenize(init.arena.allocator());
            } else {
                if (std.Io.Dir.cwd().openDir(init.io, filename, .{ .iterate = true })) |dir| {
                    // defer dir.close(); // *shrug*

                    var walker = try dir.walk(init.arena.allocator());

                    var buffer: [1000]u8 = undefined;
                    var decoder = std.base64.Base64Decoder.init(std.fs.base64_alphabet, '=');

                    while (try walker.next(init.io)) |handle| {
                        if (!std.mem.endsWith(u8, handle.path, ".html"))
                            continue;
                        const raw_address = handle.path[0 .. handle.path.len - 5];
                        const result_len = try decoder.calcSizeForSlice(raw_address);
                        try decoder.decode(&buffer, raw_address);
                        const address = buffer[0..result_len];

                        try indexer.addDocId(init.arena.allocator(), address);

                        var doc = try handle.dir.openFile(init.io, handle.path, .{});
                        defer doc.close(init.io);

                        var reader = doc.reader(init.io, &reader_buf);

                        const stat = try doc.stat(init.io);
                        const file_size = stat.size;

                        var toker = HtmlTokenizer.init(&indexer);

                        try toker.tokenize(&reader.interface, file_size);
                    }
                } else |_| {
                    std.debug.print("WARNING: Don't know how to index '{s}'\n", .{filename});
                }
            }

            try indexer.write(init.io, init.arena.allocator());
            return;
        }
    }

    // No processing was done print help
    return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});
}
