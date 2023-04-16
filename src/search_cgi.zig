//	SEARCH_CGI.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const Index = @import("index.zig").Index;
const Result = @import("index.zig").Result;
const tokenizer = @import("tokenizer.zig");
const QueryTokenizer = tokenizer.QueryTokenizer;
const Token = tokenizer.Token;
const Ranker = @import("ranking_fn.zig").Ranker;
const stem = @import("stem_s.zig").stem;

fn cmpResults(context: void, a: Result, b: Result) bool {
    return std.sort.desc(f64)(context, a.score, b.score);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var timer = try std.time.Timer.start();

    try stdout.print("Content-type: text/html; charset=utf-8\n\n", .{});

    try stdout.print("{s}", .{
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\<meta charset='utf-8'>
        \\<title>search results - Potato Castles</title>
        \\</head>
        \\<body>
        \\<h1 class='site-logo'><a href='/'>Potato Castles</a></h1>
        \\<h4>Search powered by <a href='http://github.com/vkitchen/cocomel'>cocomel</a></h4>
        \\<form class='site-search' action='/cgi-bin/search-recipes' method='get'>
        \\<input type='text' name='q' placeholder='Search recipes...'>
        \\<input type='submit' value='Search'>
        \\</form>
    });

    try stdout.print("{s}\n", .{"<p>"});

    const index_file = try file.slurp(allocator, "index.dat");
    try stdout.print("Index size {d}\n", .{index_file.len});

    try stdout.print("{s}\n", .{"<br>"});

    const index = Index.init(index_file);
    try stdout.print("No. docs {d}\n", .{index.docs_count});

    try stdout.print("{s}\n", .{"</p>"});

    var snippets_file = try std.fs.cwd().openFile("snippets.dat", .{});
    defer snippets_file.close();
    var snippets_buf: [500]u8 = undefined;

    var ranker = Ranker.init(@intToFloat(f64, index.docs_count), index.average_length);

    var results = try allocator.alloc(Result, index.docs_count);
    var i: u32 = 0;
    while (i < index.docs_count) : (i += 1) {
        results[i].doc_id = i;
        results[i].score = 0;
    }

    var query = std.os.getenv("QUERY_STRING");
    var qq = query.?[2..];
    var input = try allocator.alloc(u8, qq.len);
    std.mem.copy(u8, input, qq);

    var tok = QueryTokenizer.init(input);

    while (true) {
        const t = tok.next();
        if (t.type == Token.Type.eof) break;
        var term = stem(t.token);
        try stdout.print("<h4>Searching: {s}</h4>\n", .{term});
        index.find(term, &ranker, results);
    }

    std.sort.sort(Result, results, {}, cmpResults);

    var results_count: u32 = 0;
    for (results) |result| {
        if (result.score == 0)
            break;

        results_count += 1;
    }

    try stdout.print("<h4>Top 100 Results ({d} total):</h4>\n", .{results_count});

    try stdout.print("<ul>\n", .{});
    i = 0;
    while (i < std.math.min(100, results_count)) : (i += 1) {
        try stdout.print("<li>\n", .{});
        const name = index.name(results[i].doc_id);
        try stdout.print("{d:.4} <a href='http://{s}'>{s}</a>\n", .{ results[i].score, name[0 .. name.len - 5], name[0 .. name.len - 5] });
        try stdout.print("<p>{s}</p>\n\n", .{try index.snippet(results[i].doc_id, &snippets_buf, snippets_file)});
        try stdout.print("</li>\n", .{});
    }
    try stdout.print("</ul>\n", .{});

    try stdout.print("<p>Search took {d:.3} seconds</p>\n", .{@intToFloat(f64, timer.read()) / 1e9});

    try stdout.print("</body>\n", .{});
    try stdout.print("</html>\n", .{});
}
