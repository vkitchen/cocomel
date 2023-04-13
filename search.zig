//	SEARCH.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const index = @import("index_structure.zig");
const tokenizer = @import("tokenizer.zig");
const QueryTokenizer = tokenizer.QueryTokenizer;
const Token = tokenizer.Token;

fn cmpResults(context: void, a: index.Result, b: index.Result) bool {
    return std.sort.desc(u32)(context, a.score, b.score);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    std.debug.print("{s}\n", .{"Reading index..."});
    const index_file = try file.slurp(allocator, "index.dat");
    std.debug.print("Index size {d}\n", .{index_file.len});

    const docs_offset = index.read32(index_file, index_file.len - 8);
    const hash_offset = index.read32(index_file, index_file.len - 4);

    const docs_count = index.read32(index_file, docs_offset);
    std.debug.print("No. docs {d}\n", .{docs_count});

    var results = try allocator.alloc(index.Result, docs_count);
    var i: u32 = 0;
    while (i < docs_count) : (i += 1) {
        results[i].doc_id = i;
        results[i].score = 0;
    }

    std.debug.print("{s}", .{"Query> "});
    const stdin = std.io.getStdIn().reader();

    var buf: [100]u8 = undefined;
    var input = try stdin.readUntilDelimiterOrEof(&buf, '\n');

    var tok = QueryTokenizer.init(input.?);

    while (true) {
        const t = tok.next();
        if (t.type == Token.Type.eof) break;
        index.find(index_file, hash_offset, t.token, results);
    }

    std.debug.print("Searching: {s}\n", .{input.?});
    std.sort.sort(index.Result, results, {}, cmpResults);

    var results_count: u32 = 0;
    for (results) |result| {
        if (result.score == 0)
            break;

        results_count += 1;
    }

    std.debug.print("Top 10 Results ({d} total):\n", .{results_count});

    i = 0;
    while (i < std.math.min(10, results_count)) : (i += 1) {
        std.debug.print("{s} Score: {d}\n", .{ index.name(index_file, docs_offset, results[i].doc_id), results[i].score });
    }
}
