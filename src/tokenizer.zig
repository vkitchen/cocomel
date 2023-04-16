//	TOKENIZER.ZIG
//	-------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

pub const Token = struct {
    pub const Type = enum { docno, word, none, eof };

    token: []u8,
    type: Type,
};

pub const QueryTokenizer = struct {
    const Self = @This();

    index: usize,
    doc: []u8,

    pub fn init(doc: []u8) Self {
        return .{ .index = 0, .doc = doc };
    }

    pub fn reinit(t: *Self, doc: []const u8) void {
        t.index = 0;
        t.doc = doc;
    }

    pub fn next(t: *Self) Token {
        while (true) {
            // Whitespace
            while (t.index < t.doc.len and std.ascii.isWhitespace(t.doc[t.index])) {
                t.index += 1;
            }
            // EOF
            if (t.index == t.doc.len) {
                break;
            }
            // Number
            else if (std.ascii.isDigit(t.doc[t.index])) {
                var i: usize = 0;
                while (i < 256 and i + t.index < t.doc.len and std.ascii.isDigit(t.doc[t.index + i])) {
                    i += 1;
                }

                const out = Token{
                    .token = t.doc[t.index .. t.index + i],
                    .type = Token.Type.word,
                };

                t.index += i;

                return out;
            }
            // Word
            else if (std.ascii.isAlpha(t.doc[t.index])) {
                var i: usize = 0;
                while (i < 256 and i + t.index < t.doc.len and std.ascii.isAlpha(t.doc[t.index + i])) {
                    t.doc[i] = std.ascii.toLower(t.doc[i]);
                    i += 1;
                }

                const out = Token{
                    .token = t.doc[t.index .. t.index + i],
                    .type = Token.Type.word,
                };

                t.index += i;

                return out;
            }
            // Something else we don't want
            else {
                t.index += 1;
            }
        }
        const out = Token{
            .token = t.doc[0..0],
            .type = Token.Type.eof,
        };
        return out;
    }
};

pub const Tokenizer = struct {
    const Self = @This();

    index: usize,
    doc: []u8,

    pub fn init(doc: []u8) Self {
        return .{ .index = 0, .doc = doc };
    }

    pub fn reinit(t: *Self, doc: []const u8) void {
        t.index = 0;
        t.doc = doc;
    }

    pub fn next(t: *Self, buffer: []u8) Token {
        while (true) {
            // Whitespace
            while (t.index < t.doc.len and std.ascii.isWhitespace(t.doc[t.index])) {
                t.index += 1;
            }
            // EOF
            if (t.index == t.doc.len) {
                break;
            }
            // Doc ID
            else if (std.mem.startsWith(u8, t.doc[t.index..], "<DOCNO>")) {
                t.index += std.mem.len("<DOCNO>");

                while (t.index < t.doc.len and std.ascii.isWhitespace(t.doc[t.index]))
                    t.index += 1;

                var i: usize = 0;
                while (i + t.index < t.doc.len and t.doc[t.index + i] != '<' and !std.ascii.isWhitespace(t.doc[t.index + i])) {
                    i += 1;
                }

                const out = Token{
                    .token = t.doc[t.index .. t.index + i],
                    .type = Token.Type.docno,
                };

                t.index += i;

                return out;
            }
            // Ignored tags
            else if (t.doc[t.index] == '<') {
                t.index += 1;
                while (t.index < t.doc.len and t.doc[t.index] != '>')
                    t.index += 1;
                t.index += 1;
                continue;
            }
            // Number
            else if (std.ascii.isDigit(t.doc[t.index])) {
                var i: usize = 0;
                while (i < buffer.len and i + t.index < t.doc.len and std.ascii.isDigit(t.doc[t.index + i])) {
                    buffer[i] = t.doc[t.index + i];
                    i += 1;
                }

                const out = Token{
                    .token = buffer[0..i],
                    .type = Token.Type.word,
                };

                t.index += i;

                return out;
            }
            // Word
            else if (std.ascii.isAlpha(t.doc[t.index])) {
                var i: usize = 0;
                while (i < buffer.len and i + t.index < t.doc.len and std.ascii.isAlpha(t.doc[t.index + i])) {
                    buffer[i] = std.ascii.toLower(t.doc[t.index + i]);
                    i += 1;
                }

                const out = Token{
                    .token = buffer[0..i],
                    .type = Token.Type.word,
                };

                t.index += i;

                return out;
            }
            // Something else we don't want
            else {
                t.index += 1;
            }
        }
        const out = Token{
            .token = t.doc[0..0],
            .type = Token.Type.eof,
        };
        return out;
    }
};

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

        bytes_consumed: usize = 0,
        next_header: usize = 0,
        index: usize = 0,
        len: usize = 0,
        buf: [4096]u8 = undefined,
        name_buf: [255]u8 = undefined,
        doc: ReaderType,

        pub fn init(doc: ReaderType) Self {
            return .{ .doc = doc };
        }

        fn read(t: *Self) !void {
            t.len = try t.doc.read(&t.buf);
            t.index = 0;
        }

        fn getChar(t: *Self) !u8 {
            if (t.index == t.len)
                try t.read();
            const char = t.buf[t.index];
            t.index += 1;
            t.bytes_consumed += 1;
            return char;
        }

        fn peek(t: *Self) !u8 {
            if (t.index == t.len)
                try t.read();
            return t.buf[t.index];
        }

        fn eof(t: *Self) !bool {
            if (t.index == t.len)
                try t.read();
            return t.len == 0;
        }

        fn isHeader(t: *Self) !bool {
            if (t.index == t.len)
                try t.read();
            return t.len != 0 and t.next_header == t.bytes_consumed;
        }

        fn getDocId(t: *Self) !Token {
            // Header is 512 byte aligned. Can just read
            const header: *TarHeader = @ptrCast(*TarHeader, t.buf[t.index..]);
            t.index += @sizeOf(TarHeader);
            t.bytes_consumed += @sizeOf(TarHeader);
            t.next_header += @sizeOf(TarHeader);

            if (header.typeflag == 0)
                return Token{ .type = Token.Type.eof, .token = undefined };

            if (header.typeflag == '5')
                return Token{ .type = Token.Type.none, .token = undefined };

            // TODO return this as an error
            if (header.typeflag != '0') {
                std.debug.print("ERROR: Unknown filetype '{c}' in tarball\n", .{header.typeflag});
                std.process.exit(1);
            }

            // Find next header
            const file_size = try std.fmt.parseUnsigned(u64, &header.size, 8);
            t.next_header += file_size;
            if (file_size % 512 != 0)
                t.next_header += 512 - (file_size % 512);

            // Extract full name
            var name = @ptrCast([]u8, std.mem.span(@ptrCast([*:0]u8, &header.name)));
            if (header.prefix[0] != 0) {
                var prefix = std.mem.span(@ptrCast([*:0]u8, &header.prefix));
                std.mem.copy(u8, &t.name_buf, prefix);
                t.name_buf[prefix.len] = '/';
                std.mem.copy(u8, t.name_buf[prefix.len + 1 ..], name);
                name = t.name_buf[0 .. prefix.len + 1 + name.len];
            }

            return Token{ .type = Token.Type.docno, .token = name };
        }

        pub fn next(t: *Self, buffer: []u8) !Token {
            while (true) {
                // Doc ID
                if (try t.isHeader()) {
                    const out = try t.getDocId();
                    // Empty file type
                    if (out.type == Token.Type.none)
                        continue;
                    return out;
                }

                const char = try t.getChar();
                // EOF
                if (char == 0) {
                    if (try t.eof())
                        break;
                    continue;
                }
                // Whitespace
                else if (std.ascii.isWhitespace(char)) {
                    continue;
                }
                // Ignored tags
                else if (char == '<') {
                    if (!try t.eof() and try t.getChar() == 's') {
                        const nextChar = try t.getChar();
                        if (nextChar == 'c' and try t.getChar() == 'r' and try t.getChar() == 'i' and try t.getChar() == 'p' and try t.getChar() == 't') {
                            while (!try t.eof() and try t.peek() != '<')
                                _ = try t.getChar();
                        }
                        if (nextChar == 't' and try t.getChar() == 'y' and try t.getChar() == 'l' and try t.getChar() == 'e') {
                            while (!try t.eof() and try t.peek() != '<')
                                _ = try t.getChar();
                        }
                    }
                    while (!try t.eof() and try t.peek() != '>')
                        _ = try t.getChar();
                    continue;
                }
                // Number
                else if (std.ascii.isDigit(char)) {
                    buffer[0] = char;

                    var i: usize = 1;
                    while (i < buffer.len and !try t.eof() and std.ascii.isDigit(try t.peek())) : (i += 1)
                        buffer[i] = try t.getChar();

                    return Token{
                        .token = buffer[0..i],
                        .type = Token.Type.word,
                    };
                }
                // Word
                else if (std.ascii.isAlpha(char)) {
                    buffer[0] = char;

                    var i: usize = 1;
                    while (i < buffer.len and !try t.eof() and (std.ascii.isAlpha(try t.peek()) or try t.peek() == '\'')) : (i += 1)
                        buffer[i] = try t.getChar();
                    if (try t.peek() == ',' or try t.peek() == '.') {
                        buffer[i] = try t.getChar();
                        i += 1;
                    }

                    return Token{
                        .token = buffer[0..i],
                        .type = Token.Type.word,
                    };
                }
            }
            std.debug.print("Fell off the world at {d} {d}\n", .{ t.bytes_consumed, t.index });
            return Token{
                .token = undefined,
                .type = Token.Type.eof,
            };
        }
    };
}
