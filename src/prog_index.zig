// PROG_INDEX.ZIG
// --------------
// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const clap = @import("clap");

const config = @import("config.zig");
const HtmlTokenizer = @import("tokenizer_html.zig").HtmlTokenizer;
const WsjTokenizer = @import("tokenizer_wsj.zig").WsjTokenizer;
const TarTokenizer = @import("tokenizer_tar.zig").TarTokenizer;
const Stemmer = @import("stem.zig").Stemmer;
const compress = @import("compress_int.zig");
const Indexer = @import("indexer.zig").Indexer;
const CcmlSerialiser = @import("serialiser_ccml.zig").CcmlSerialiser;

var reader_buf: [config.io_buffer_size]u8 = undefined;
var filename_buf: [1000]u8 = undefined;

var base64_decoder = std.base64.Base64Decoder.init(std.fs.base64_alphabet, '=');

fn decode_filename(filename: []const u8) ![]u8 {
    const result_len = try base64_decoder.calcSizeForSlice(filename);
    try base64_decoder.decode(&filename_buf, filename);
    return filename_buf[0..result_len];
}

pub fn main(init: std.process.Init) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\--base64               Filenames are in base64.
        \\--snippets             Whether to generate a snippet index for the input.
        \\--bigrams              Whether to include bigrams in index.
        \\--wsj                  Whether the files to index are in trec wsj format.
        \\--stem <name>          Stemmer to use. Only "s" supported.
        \\--compress <name>      Compressor to use:
        \\                         * bp128 Packs 128 integers at a time into blocks (fast, default)
        \\                         * vbyte Packs integers into variable number of bytes (slow)
        \\<file>...
        \\
    );

    const cli_parsers = comptime .{
        .name = clap.parsers.string,
        .file = clap.parsers.string,
    };

    var res = try clap.parse(clap.Help, &params, cli_parsers, init.minimal.args, .{ .allocator = init.arena.allocator() });
    defer res.deinit();

    var stemmer = Stemmer.init(Stemmer.Alg.none);

    if (res.args.stem) |alg| {
        if (std.mem.eql(u8, alg, "s")) {
            stemmer = Stemmer.init(Stemmer.Alg.s);
        } else {
            std.debug.print("Unknown stemmer {s}\n", .{alg});
            std.process.exit(1);
        }
    }

    var compressor = compress.default;
    if (res.args.compress) |alg| {
        compressor = compress.fromName(alg);
        if (compressor == .failed) {
            std.debug.print("Unknown compressor {s}\n", .{alg});
            std.process.exit(1);
        }
    }

    var serialiser = try CcmlSerialiser.init(init.io, res.args.snippets != 0);

    var indexer = try Indexer.init(init.arena.allocator(), stemmer, &serialiser, res.args.bigrams != 0);

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

        try indexer.write(init.io, init.arena.allocator(), compressor);
        std.debug.print("Terms count {d}\n", .{indexer.vocab.len});
        std.debug.print("Memory usage {Bi:.2}\n", .{init.arena.queryCapacity()});
        return;
    } else {
        for (res.positionals[0]) |filename| {
            var file = try std.Io.Dir.cwd().openFile(init.io, filename, .{});
            defer file.close(init.io);

            const stat = try file.stat(init.io);

            if (stat.kind == .directory) {
                var dir = try std.Io.Dir.cwd().openDir(init.io, filename, .{ .iterate = true });
                // defer dir.close(); // *shrug*

                var walker = try dir.walk(init.arena.allocator());

                while (try walker.next(init.io)) |handle| {
                    if (!std.mem.endsWith(u8, handle.path, ".html"))
                        continue;

                    const file_stem = handle.path[0 .. handle.path.len - 5];
                    const doc_id = if (res.args.base64 != 0) try decode_filename(file_stem) else handle.path;

                    try indexer.addDocId(init.arena.allocator(), doc_id);

                    var doc = try handle.dir.openFile(init.io, handle.path, .{});
                    defer doc.close(init.io);

                    var reader = doc.reader(init.io, &reader_buf);

                    var toker = HtmlTokenizer.init(&indexer, &reader.interface);
                    try toker.tokenize(init.arena.allocator());
                }
            } else if (std.mem.endsWith(u8, filename, ".html")) {
                const file_stem = std.fs.path.stem(filename);
                const doc_id = if (res.args.base64 != 0) try decode_filename(file_stem) else filename;

                try indexer.addDocId(init.arena.allocator(), doc_id);

                var reader = file.reader(init.io, &reader_buf);

                var toker = HtmlTokenizer.init(&indexer, &reader.interface);
                try toker.tokenize(init.arena.allocator());
                //            } else if (std.mem.endsWith(u8, filename, ".tar.gz")) {
                //                var reader = file.reader(init.io, &reader_buf);
                //
                //                var gzip_buf: [std.compress.flate.max_window_len]u8 = undefined;
                //                var gzip_stream = std.compress.flate.Decompress.init(&reader.interface, .gzip, &gzip_buf);
                //
                //                var toker = TarTokenizer.init(&indexer, &gzip_stream.reader);
                //                try toker.tokenize(init.arena.allocator());
            } else {
                std.debug.print("WARNING: Don't know how to index '{s}'\n", .{filename});
            }
        }

        try indexer.write(init.io, init.arena.allocator(), compressor);
        std.debug.print("Terms count {d}\n", .{indexer.vocab.len});
        std.debug.print("Memory usage {Bi:.2}\n", .{init.arena.queryCapacity()});
        return;
    }

    // No processing was done print help
    return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});
}
