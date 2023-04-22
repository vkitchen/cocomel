//	CLIENT_CGI.ZIG
//	--------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Search = @import("search.zig").Search;
const str = @import("str.zig");

const socket_name = "/tmp/cocomel.sock";

fn read16(buf: []const u8, offset: usize) u16 {
    return std.mem.bytesToValue(u16, buf[offset .. offset + @sizeOf(u16)][0..2]);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var q = std.os.getenv("QUERY_STRING");
    var query = try str.dup(allocator, q.?[2..]);

    var buf: [1000]u8 = undefined;
    buf[0] = 0;
    buf[1] = 0;
    const len = @truncate(u16, query.len);
    const lenp = std.mem.asBytes(&len);
    std.mem.copy(u8, buf[2..], lenp);
    std.mem.copy(u8, buf[4..], query);

    var results_buffer: [16384]u8 = undefined;

    var timer = try std.time.Timer.start();

    var stream = try std.net.connectUnixSocket(socket_name);

    _ = try stream.write(buf[0 .. 4 + query.len]);

    var total_read: usize = 0;
    while (true) {
        var bytes_read = try stream.read(results_buffer[total_read..]);
        if (bytes_read == 0)
            break;
        total_read += bytes_read;
    }

    stream.close();

    const search_time = timer.read();

    const no_results = read16(&results_buffer, 0);

    try stdout.print("Content-type: text/html; charset=utf-8\n\n", .{});

    try stdout.print(
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\<meta charset='utf-8'>
        \\<link rel='stylesheet' type='text/css' href='/static/main.css'>
        \\<title>search results - Potato Castles</title>
        \\</head>
        \\<body>
        \\<div class='header'>
        \\<h1 class='logo'><a href='/'>Potato Castles</a></h1>
        \\<form class='site-search' action='/cgi-bin/search-recipes' method='get'>
        \\<input class='search-input' type='text' name='q' placeholder='Search recipes...'><!--
        \\--><input class='search-submit' type='submit' value='Search'>
        \\</form>
        \\<h4>Approx {d} results in {d:.3} seconds</h4>
        \\</div>
    , .{ no_results, @intToFloat(f64, search_time) / 1e9 });

    try stdout.print("<ul>\n", .{});
    var offset: usize = 2;

    var i: usize = 0;
    while (i < no_results) : (i += 1) {
        try stdout.print("<li>\n", .{});
        const name_len = read16(&results_buffer, offset);
        offset += 2;
        const name = results_buffer[offset .. offset + name_len];
        try stdout.print("<a href='http://{s}'>{s}</a>\n", .{ name, name });
        offset += name_len;
        const snippet_len = read16(&results_buffer, offset);
        offset += 2;
        try stdout.print("<p>{s}</p>\n\n", .{results_buffer[offset .. offset + snippet_len]});
        offset += snippet_len;
        try stdout.print("</li>\n", .{});
    }
    try stdout.print("</ul>\n", .{});
    try stdout.print("</body>\n", .{});
    try stdout.print("</html>\n", .{});
}
