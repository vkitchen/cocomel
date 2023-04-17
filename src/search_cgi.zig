//	SEARCH_CGI.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const file = @import("file.zig");
const Index = @import("index.zig").Index;
const Result = @import("index.zig").Result;
const Token = @import("tokenizer.zig").Token;
const QueryTokenizer = @import("tokenizer_query.zig").QueryTokenizer;
const Ranker = @import("ranking_fn_bm25.zig").Ranker;
const stem = @import("stem_s.zig").stem;
const expandQuery = @import("query_expansion.zig").expandQuery;
const Search = @import("search.zig").Search;
const slice = @import("slice.zig");

fn cmpResults(context: void, a: Result, b: Result) bool {
    return std.sort.desc(f64)(context, a.score, b.score);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var snippets_buf: [500]u8 = undefined;

    var searcher = try Search.init(allocator, &snippets_buf);
    defer searcher.deinit();

    var q = std.os.getenv("QUERY_STRING");
    var query = try slice.dup(allocator, q.?[2..]);

    const results = try searcher.search(allocator, query);

    var timer = try std.time.Timer.start();

    try stdout.print("Content-type: text/html; charset=utf-8\n\n", .{});

    try stdout.print(
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
    , .{});

    try stdout.print("<h4>Top 30 Results ({d} total):</h4>\n", .{results.len});

    try stdout.print("<ul>\n", .{});
    {
        var i: u32 = 0;
        while (i < std.math.min(30, results.len)) : (i += 1) {
            try stdout.print("<li>\n", .{});
            const name = searcher.name(results[i].doc_id);
            try stdout.print("{d:.4} <a href='http://{s}'>{s}</a>\n", .{ results[i].score, name[0 .. name.len - 5], name[0 .. name.len - 5] });
            try stdout.print("<p>{s}</p>\n\n", .{try searcher.snippet(results[i].doc_id)});
            try stdout.print("</li>\n", .{});
        }
    }
    try stdout.print("</ul>\n", .{});

    var time_write_out = timer.read();

    try stdout.print("<h4>Debugging information</h4>\n", .{});
    try stdout.print("<p>\n", .{});

    try stdout.print("Index size: {d:.3}MiB<br>\n", .{@intToFloat(f64, searcher.index.index.len) / 1024 / 1024});
    try stdout.print("No. docs: {d}<br>\n", .{searcher.index.docs_count});

    for (searcher.terms.items) |term, i| {
        try stdout.print("Term {d}: {s}<br>\n", .{ i, term });
    }

    try stdout.print("<p>\n", .{});

    try stdout.print("<h4>Timing information</h4>\n", .{});
    try stdout.print("<p>\n", .{});

    try stdout.print("Index read took {d:.3} seconds<br>\n", .{@intToFloat(f64, searcher.time_index) / 1e9});
    try stdout.print("Query parsing took {d:.3} seconds<br>\n", .{@intToFloat(f64, searcher.time_query) / 1e9});
    try stdout.print("Searching took {d:.3} seconds<br>\n", .{@intToFloat(f64, searcher.time_search) / 1e9});
    try stdout.print("Writing results took {d:.3} seconds<br>\n", .{@intToFloat(f64, time_write_out) / 1e9});

    try stdout.print("</p>\n", .{});

    try stdout.print("</body>\n", .{});
    try stdout.print("</html>\n", .{});
}
