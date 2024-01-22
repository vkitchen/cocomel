//	TOKENIZER_TAR.ZIG
//	-----------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Indexer = @import("indexer.zig").Indexer;
const HtmlTokenizer = @import("tokenizer_html.zig").HtmlTokenizer;

fn rtrim(str: []u8) []u8 {
    var end = str.len;
    while (end > 0) : (end -= 1)
        if (str[end - 1] != 0)
            break;
    return str[0..end];
}

const TarHeader = extern struct {
    const Self = @This();

    name: [100]u8,
    mode: [8]u8,
    uid: [8]u8,
    gid: [8]u8,
    size: [11:0]u8,
    mtime: [12]u8,
    chksum: [8]u8,
    typeflag: u8,
    linkname: [100]u8,
    magic: [6]u8,
    version: [2]u8,
    uname: [32]u8,
    gname: [32]u8,
    devmajor: [8]u8,
    devminor: [8]u8,
    prefix: [155]u8,

    pad: [12]u8, // unused

    fn fileSize(self: *Self) !u64 {
        return try std.fmt.parseUnsigned(u64, &self.size, 8);
    }

    fn fullName(self: *Self, buffer: []u8) []u8 {
        const name = rtrim(&self.name);
        if (self.prefix[0] == 0)
            return name;
        const prefix = rtrim(&self.prefix);
        @memcpy(buffer, prefix);
        buffer[prefix.len] = '/';
        @memcpy(buffer[prefix.len + 1 ..], name);
        return buffer[0 .. prefix.len + 1 + name.len];
    }
};

pub fn TarTokenizer(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        indexer: *Indexer,
        buf: [512]u8 = undefined, // Tar block size
        name_buf: [256]u8 = undefined,
        doc: ReaderType,
        toker: HtmlTokenizer(ReaderType) = undefined,

        pub fn init(indexer: *Indexer, doc: ReaderType) Self {
            return .{
                .indexer = indexer,
                .doc = doc,
                .toker = HtmlTokenizer(ReaderType).init(indexer),
            };
        }

        pub fn tokenize(self: *Self) !void {
            while (true) {
                if (try self.doc.read(&self.buf) != 512)
                    return;

                const header: *TarHeader = @ptrCast(&self.buf);

                _ = switch (header.typeflag) {
                    0 => return,
                    '0' => {},
                    '5' => continue,
                    else => std.debug.panic("unimplemented", .{}),
                };

                try self.indexer.addDocId(header.fullName(&self.name_buf));

                const file_size = try header.fileSize();
                if (file_size == 0)
                    continue;
                try self.toker.tokenize(&self.doc, file_size);
            }
        }
    };
}
