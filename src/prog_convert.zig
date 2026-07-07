// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

const std = @import("std");
const clap = @import("clap");
const protobuf = @import("protobuf");
const ciff = @import("proto/io/osirrc/ciff.pb.zig");
const CcmlSerialiser = @import("serialiser_ccml.zig");
const HashMap = @import("hash_map.zig").HashMap;
const Postings = @import("postings.zig");
const compress = @import("compress_int.zig");
const Stemmer = @import("stem.zig").Stemmer;
const config = @import("config.zig");
const Doc = @import("doc.zig");

var reader_buf: [4096]u8 = undefined;
var limited_buf: [4096]u8 = undefined;

fn takeVByte(reader: *std.Io.Reader) !u64 {
    var result: u64 = 0;
    var byte = try reader.takeByte();

    var i: u6 = 0;
    while (byte & (1 << 7) != 0) : (i += 1) {
        result |= @as(u64, byte & ((1 << 7) - 1)) << 7 * i;
        byte = try reader.takeByte();
    }
    result |= @as(u64, byte & ((1 << 7) - 1)) << 7 * i;

    return result;
}

pub fn main(init: std.process.Init) !void {
    var arena = init.arena.allocator();
    var scratch_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const scratch = scratch_allocator.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\--ciff <file>          Convert from ciff index.
        \\--quantise             Ciff needs quantising?
        \\--compress <name>      Compressor to use:
        \\                         * bp128 Packs 128 integers at a time into blocks (fast, default)
        \\                         * vbyte Packs integers into variable number of bytes (slow)
        \\
    );

    const cli_parsers = comptime .{
        .name = clap.parsers.string,
        .file = clap.parsers.string,
    };

    var res = try clap.parse(clap.Help, &params, cli_parsers, init.minimal.args, .{ .allocator = arena });
    defer res.deinit();

    if (res.args.help != 0) {
        return clap.helpToFile(init.io, .stderr(), clap.Help, &params, .{});
    }

    var compressor = compress.default;
    if (res.args.compress) |alg| {
        compressor = compress.fromName(alg);
        if (compressor == .failed) {
            std.debug.print("Unknown compressor {s}\n", .{alg});
            std.process.exit(1);
        }
    }

    if (res.args.ciff) |filename| {
        var file = try std.Io.Dir.cwd().openFile(init.io, filename, .{});
        defer file.close(init.io);

        var reader = file.reader(init.io, &reader_buf);

        var len = try takeVByte(&reader.interface);
        var limited = reader.interface.limited(std.Io.Limit.limited(len), &limited_buf);

        var header = try ciff.Header.decode(&limited.interface, scratch);
        defer header.deinit(scratch);

        var doc_ids: std.ArrayList(Doc) = try std.ArrayList(Doc).initCapacity(arena, @intCast(header.num_docs));
        var vocab = try HashMap(*Postings).initCapacity(arena, @intCast(header.num_postings_lists));

        for (0..@intCast(header.num_postings_lists)) |i| {
            len = try takeVByte(&reader.interface);
            limited = reader.interface.limited(std.Io.Limit.limited(len), &limited_buf);

            var postings_list = try ciff.PostingsList.decode(&limited.interface, scratch);
            defer postings_list.deinit(scratch);

            var last_docid: u32 = 0;
            const postings = try vocab.emplace(arena, postings_list.term);
            for (postings_list.postings.items) |p| {
                const docid = last_docid + @as(u32, @intCast(p.docid));
                const tf: config.TermFrequencyType = @truncate(@as(u32, @intCast(std.math.clamp(p.tf, 0, std.math.maxInt(config.TermFrequencyType)))));

                if (postings.* == null) {
                    const post = try arena.create(Postings);
                    post.* = try Postings.initCapacity(arena, postings_list.postings.items.len);
                    post.id = docid;
                    post.freq = tf;
                    postings.* = post;

                    last_docid = docid;
                    continue;
                }

                const post = postings.*.?;

                try post.flush(arena);
                post.id = docid;
                post.freq = tf;

                last_docid = docid;
            }
            postings.*.?.len = @intCast(postings_list.df);

            if (i != 0 and i % 1_000_000 == 0)
                std.debug.print("Read {d}/{d} postings\n", .{ i, header.num_postings_lists });
        }

        std.debug.print("Read {d}/{d} postings\n", .{ header.num_postings_lists, header.num_postings_lists });

        for (0..@intCast(header.num_docs)) |i| {
            len = try takeVByte(&reader.interface);
            limited = reader.interface.limited(std.Io.Limit.limited(len), &limited_buf);

            var doc = try ciff.DocRecord.decode(&limited.interface, scratch);
            defer doc.deinit(scratch);

            // TODO this is unexpected but technically allowed
            if (doc.docid != i) {
                std.debug.print("Fatal: docid {d} appeared out of order in ciff. Expected docid {d}\n", .{ doc.docid, i });
                std.process.exit(1);
            }
            doc_ids.appendAssumeCapacity(.{ .name = try arena.dupe(u8, doc.collection_docid), .len = @intCast(doc.doclength) });

            if (i != 0 and i % 1_000_000 == 0)
                std.debug.print("Read {d}/{d} docs\n", .{ i, header.num_docs });
        }

        std.debug.print("Read {d}/{d} docs\n", .{ header.num_docs, header.num_docs });

        std.debug.print("Writing index...\n", .{});
        var serialiser = try CcmlSerialiser.init(init.io, false);
        _ = try serialiser.write(init.io, arena, &doc_ids, &vocab, compressor, Stemmer.Alg.none, res.args.quantise != 0);
    }
}
