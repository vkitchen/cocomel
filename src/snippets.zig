//	SNIPPETS.ZIG
//	------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Tokenizer = @import("tokenizer_snippet.zig").Tokenizer;
const Term = @import("tokenizer_snippet.zig").Term;

fn copy_to_buf(buffer: []u8, terms: *std.ArrayList(Term), offset: usize) []u8 {
    var bytes_written: usize = 0;
    var i = offset;
    var end = std.math.min(terms.items.len, offset + 100);
    while (i < end) : (i += 1) {
        if (bytes_written + 4 + terms.items[i].original.len + 4 >= buffer.len)
            break;
        if (bytes_written > 0) {
            buffer[bytes_written] = ' ';
            bytes_written += 1;
        }
        if (terms.items[i].hit) {
            std.mem.copy(u8, buffer[bytes_written..], "<b>");
            bytes_written += 3;
        }
        std.mem.copy(u8, buffer[bytes_written..], terms.items[i].original);
        bytes_written += terms.items[i].original.len;
        if (terms.items[i].hit) {
            std.mem.copy(u8, buffer[bytes_written..], "</b>");
            bytes_written += 4;
        }
    }
    return buffer[0..bytes_written];
}

pub fn snippet(allocator: std.mem.Allocator, query: std.ArrayList([]u8), file: std.fs.File, start: usize, end: usize) ![]u8 {
    var tok = Tokenizer.init(file);
    var tokens = std.ArrayList(Term).init(allocator);
    try tok.tokenize(allocator, &tokens, start, end);

    var buffer = try allocator.alloc(u8, 4096);
    const window = std.math.min(100, tokens.items.len);
    if (window < 100)
        return copy_to_buf(buffer, &tokens, 0);

    var hits: usize = 0;
    var max_hits: usize = 0;
    var max_hits_i: usize = 0;
    var i: usize = 0;
    while (i < window) : (i += 1) {
        for (query.items) |q| {
            if (std.mem.eql(u8, q, tokens.items[i].stemmed)) {
                tokens.items[i].hit = true;
                hits += 1;
                break;
            }
        }
    }
    max_hits = hits;

    while (i < tokens.items.len) : (i += 1) {
        if (tokens.items[i - 100].hit)
            hits -= 1;
        for (query.items) |q| {
            if (std.mem.eql(u8, q, tokens.items[i].stemmed)) {
                tokens.items[i].hit = true;
                hits += 1;
                break;
            }
        }
        if (hits > max_hits) {
            max_hits = hits;
            max_hits_i = i;
        }
    }

    return copy_to_buf(buffer, &tokens, max_hits_i);
}
