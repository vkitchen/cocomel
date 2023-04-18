//	TOKENIZER_TAR.ZIG
//	-----------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Indexer = @import("indexer.zig").Indexer;
const Token = @import("tokenizer.zig").Token;

const TarHeader = extern struct {
    name: [99:0]u8,
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
};

pub fn TarTokenizer(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        indexer: *Indexer,
        bytes_consumed: usize = 0,
        next_header: usize = 0,
        index: usize = 0,
        len: usize = 0,
        buf: [4096]u8 = undefined,
        name_buf: [255]u8 = undefined,
        doc: ReaderType,
        should_exit: bool = false,

        pub fn init(indexer: *Indexer, doc: ReaderType) Self {
            return .{ .indexer = indexer, .doc = doc };
        }

        fn read(self: *Self) !void {
            self.len = try self.doc.read(&self.buf);
            self.index = 0;
        }

        fn getChar(self: *Self) !u8 {
            if (self.index == self.len)
                try self.read();
            const char = self.buf[self.index];
            self.index += 1;
            self.bytes_consumed += 1;
            return char;
        }

        fn peek(self: *Self) !u8 {
            if (self.index == self.len)
                try self.read();
            return self.buf[self.index];
        }

        fn eof(self: *Self) !bool {
            if (self.index == self.len)
                try self.read();
            return self.len == 0;
        }

        fn isHeader(self: *Self) !bool {
            if (self.index == self.len)
                try self.read();
            return self.len != 0 and self.next_header == self.bytes_consumed;
        }

        fn getDocId(self: *Self) !?[]u8 {
            // Header is 512 byte aligned. Can just read
            const header: *TarHeader = @ptrCast(*TarHeader, self.buf[self.index..]);
            self.index += @sizeOf(TarHeader);
            self.bytes_consumed += @sizeOf(TarHeader);
            self.next_header += @sizeOf(TarHeader);

            if (header.typeflag == 0) {
                self.should_exit = true;
                return null;
            }

            if (header.typeflag == '5')
                return null;

            // TODO return this as an error
            if (header.typeflag != '0') {
                std.debug.print("ERROR: Unknown filetype '{c}' in tarball\n", .{header.typeflag});
                std.process.exit(1);
            }

            // Find next header
            const file_size = try std.fmt.parseUnsigned(u64, &header.size, 8);
            self.next_header += file_size;
            if (file_size % 512 != 0)
                self.next_header += 512 - (file_size % 512);

            // Extract full name
            var name = @ptrCast([]u8, std.mem.span(@ptrCast([*:0]u8, &header.name)));
            if (header.prefix[0] != 0) {
                var prefix = std.mem.span(@ptrCast([*:0]u8, &header.prefix));
                std.mem.copy(u8, &self.name_buf, prefix);
                self.name_buf[prefix.len] = '/';
                std.mem.copy(u8, self.name_buf[prefix.len + 1 ..], name);
                name = self.name_buf[0 .. prefix.len + 1 + name.len];
            }

            return name;
        }

        pub fn tokenize(self: *Self) !void {
            while (true) {
                // Doc ID
                if (try self.isHeader()) {
                    const name = try self.getDocId();
                    // Empty file type
                    if (name == null) {
                        if (self.should_exit)
                            return;
                        continue;
                    }
                    try self.indexer.addDocId(name.?);
                    continue;
                }

                const char = try self.getChar();
                // EOF
                if (char == 0) {
                    if (try self.eof())
                        return;
                    continue;
                }
                // Whitespace
                else if (std.ascii.isWhitespace(char)) {
                    continue;
                }
                // Ignored tags
                else if (char == '<') {
                    if (!try self.eof() and try self.getChar() == 's') {
                        const nextChar = try self.getChar();
                        if (nextChar == 'c' and try self.getChar() == 'r' and try self.getChar() == 'i' and try self.getChar() == 'p' and try self.getChar() == 't') {
                            while (!try self.eof() and try self.peek() != '<')
                                _ = try self.getChar();
                        }
                        if (nextChar == 't' and try self.getChar() == 'y' and try self.getChar() == 'l' and try self.getChar() == 'e') {
                            while (!try self.eof() and try self.peek() != '<')
                                _ = try self.getChar();
                        }
                    }
                    while (!try self.eof() and try self.peek() != '>')
                        _ = try self.getChar();
                    continue;
                }
                // Number
                else if (std.ascii.isDigit(char)) {
                    self.indexer.buffer[0] = char;

                    var i: usize = 1;
                    while (i < self.indexer.buffer.len and !try self.eof() and std.ascii.isDigit(try self.peek())) : (i += 1)
                        self.indexer.buffer[i] = try self.getChar();

                    try self.indexer.addDirtyTerm(self.indexer.buffer[0..i]);
                    continue;
                }
                // Word
                else if (std.ascii.isAlpha(char)) {
                    self.indexer.buffer[0] = char;

                    var i: usize = 1;
                    while (i < self.indexer.buffer.len and !try self.eof() and (std.ascii.isAlpha(try self.peek()) or try self.peek() == '\'')) : (i += 1)
                        self.indexer.buffer[i] = try self.getChar();
                    if (try self.peek() == ',' or try self.peek() == '.') {
                        self.indexer.buffer[i] = try self.getChar();
                        i += 1;
                    }

                    try self.indexer.addDirtyTerm(self.indexer.buffer[0..i]);
                    continue;
                }
            }
        }
    };
}
