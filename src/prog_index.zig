//	PROG_INDEX.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const cli = @import("zig-cli");

const HtmlTokenizer = @import("tokenizer_html_file.zig").HtmlFileTokenizer;
const WsjTokenizer = @import("tokenizer_wsj.zig").WsjTokenizer;
const TarTokenizer = @import("tokenizer_tar.zig").TarTokenizer;
const Indexer = @import("indexer.zig").Indexer;

var options = struct {
    trec: bool = false,
    files: []const []const u8 = undefined,
}{};

var trec_option = cli.Option{
    .long_name = "trec",
    .help = "whether the file to index is in trec format",
    .value_ref = cli.mkRef(&options.trec),
};

var files_arg = cli.PositionalArg{
    .name = "files",
    .help = "list of files or folders to index",
    .value_ref = cli.mkRef(&options.files),
};

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

const allocator = arena.allocator();

var app = &cli.App{ .command = cli.Command{ .name = "index", .description = cli.Description{
    .one_line = "indexer for the cocomel search engine",
}, .options = &.{&trec_option}, .target = cli.CommandTarget{ .action = cli.CommandAction{
    .positional_args = cli.PositionalArgs{ .args = &.{&files_arg} },
    .exec = index,
} } } };

pub fn main() !void {
    return cli.run(app, allocator);
}

fn index() !void {
    var indexer = try Indexer.init(allocator);

    if (options.trec) {
        for (options.files) |filename| {
            if (std.mem.endsWith(u8, filename, ".xml")) {
                var doc = try std.fs.cwd().openFile(filename, .{});
                defer doc.close();

                const tokerType = WsjTokenizer(@TypeOf(doc));

                var toker = try tokerType.init(&indexer, doc);
                try toker.tokenize();
            } else {
                std.debug.print("WARNING: Don't know how to index '{s}'\n", .{filename});
            }
        }
    } else {
        for (options.files) |filename| {
            if (std.mem.endsWith(u8, filename, ".tar.gz")) {
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
    }

    try indexer.write();
}
