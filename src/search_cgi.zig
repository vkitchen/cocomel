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

fn cmpResults(context: void, a: Result, b: Result) bool {
    return std.sort.desc(f64)(context, a.score, b.score);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var timer = try std.time.Timer.start();

    const index_file = try file.slurp(allocator, "index.dat");
    const index = Index.init(index_file);

    var time_index_read = timer.lap();

    var snippets_file = try std.fs.cwd().openFile("snippets.dat", .{});
    defer snippets_file.close();
    var snippets_buf: [500]u8 = undefined;

    var ranker = Ranker.init(@intToFloat(f64, index.docs_count), index.average_length);

    var results = try allocator.alloc(Result, index.docs_count);
    {
        var i: u32 = 0;
        while (i < index.docs_count) : (i += 1) {
            results[i].doc_id = i;
            results[i].score = 0;
        }
    }

    var time_init = timer.lap();

    var q = std.os.getenv("QUERY_STRING");
    var qq = q.?[2..];
    var input = try allocator.alloc(u8, qq.len);
    std.mem.copy(u8, input, qq);

    var tok = QueryTokenizer.init(input);

    var query = std.ArrayList([]u8).init(allocator);

    while (true) {
        const t = tok.next();
        if (t.type == Token.Type.eof) break;
        var term = stem(t.token);
        try query.append(term);
    }

    var time_query_parse = timer.lap();

    try expandQuery(allocator, &query);

    var time_query_expansion = timer.lap();

    for (query.items) |term| {
        index.find(term, &ranker, results);
    }

    std.sort.sort(Result, results, {}, cmpResults);

    var time_search = timer.lap();

    var results_count: u32 = 0;
    for (results) |result| {
        if (result.score == 0)
            break;

        results_count += 1;
    }

    var time_count_results = timer.lap();

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

    try stdout.print("<h4>Top 30 Results ({d} total):</h4>\n", .{results_count});

    try stdout.print("<ul>\n", .{});
    {
        var i: u32 = 0;
        while (i < std.math.min(30, results_count)) : (i += 1) {
            try stdout.print("<li>\n", .{});
            const name = index.name(results[i].doc_id);
            try stdout.print("{d:.4} <a href='http://{s}'>{s}</a>\n", .{ results[i].score, name[0 .. name.len - 5], name[0 .. name.len - 5] });
            try stdout.print("<p>{s}</p>\n\n", .{try index.snippet(results[i].doc_id, &snippets_buf, snippets_file)});
            try stdout.print("</li>\n", .{});
        }
    }
    try stdout.print("</ul>\n", .{});

    var time_write_out = timer.read();

    try stdout.print("<h4>Debugging information</h4>\n", .{});
    try stdout.print("<p>\n", .{});

    try stdout.print("Index size: {d:.3}MiB<br>\n", .{@intToFloat(f64, index_file.len) / 1024 / 1024});
    try stdout.print("No. docs: {d}<br>\n", .{index.docs_count});

    for (query.items) |term, i| {
        try stdout.print("Term {d}: {s}<br>\n", .{ i, term });
    }

    try stdout.print("<p>\n", .{});

    try stdout.print("<h4>Timing information</h4>\n", .{});
    try stdout.print("<p>\n", .{});

    try stdout.print("Index read took {d:.3} seconds<br>\n", .{@intToFloat(f64, time_index_read) / 1e9});
    try stdout.print("Init took {d:.3} seconds<br>\n", .{@intToFloat(f64, time_init) / 1e9});
    try stdout.print("Query parsing took {d:.3} seconds<br>\n", .{@intToFloat(f64, time_query_parse) / 1e9});
    try stdout.print("Query expansion took {d:.3} seconds<br>\n", .{@intToFloat(f64, time_query_expansion) / 1e9});
    try stdout.print("Search took {d:.3} seconds<br>\n", .{@intToFloat(f64, time_search) / 1e9});
    try stdout.print("Counting results took {d:.3} seconds<br>\n", .{@intToFloat(f64, time_count_results) / 1e9});
    try stdout.print("Writing results took {d:.3} seconds<br>\n", .{@intToFloat(f64, time_write_out) / 1e9});

    try stdout.print("</p>\n", .{});

    try stdout.print("</body>\n", .{});
    try stdout.print("</html>\n", .{});
}
