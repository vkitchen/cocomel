//	INDEX.ZIG
//	---------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const hashtable = @import("hash_table.zig");

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

    std.debug.print("{s} {s}\n", .{ args[0], args[1] });

    const doc = try file.slurp(allocator, args[1]);

    var tok = Tokenizer.init(doc);

    const dictionary = try allocator.create(hashtable.HashTable);
    hashtable.init(dictionary);

    var doc_count: usize = 0;
    while (true) {
        const t = tok.next();
        if (t.type == Token.Type.eof) break;
        if (t.type == Token.Type.docno) {
            if (doc_count > 0 and doc_count % 1000 == 0)
                std.debug.print("{d} Documents\n", .{doc_count});
            doc_count += 1;
        }
        try hashtable.insert(dictionary, allocator, t.token);
    }

    std.debug.print("{s}\n", .{"Finished indexing"});
    std.debug.print("{s}\n", .{"Writing indexing"});

    const index_file = try std.fs.cwd().createFile("index.dat", .{});
    defer index_file.close();
    try hashtable.write(dictionary, index_file);
}
