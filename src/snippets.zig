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

pub fn snippet(allocator: std.mem.Allocator, query: std.ArrayList([]u8), terms: *std.ArrayList(Term), file: std.fs.File, start: usize, end: usize) ![]Term {
    var tok = Tokenizer.init(file);
    try tok.tokenize(allocator, terms, start, end);

    const window = std.math.min(100, terms.items.len);
    if (window < 100)
        return terms.items;

    var hits: usize = 0;
    var max_hits: usize = 0;
    var max_hits_i: usize = 0;
    var i: usize = 0;
    while (i < window) : (i += 1) {
        for (query.items) |q| {
            if (std.mem.eql(u8, q, terms.items[i].stemmed)) {
                terms.items[i].hit = true;
                hits += 1;
                break;
            }
        }
    }
    max_hits = hits;

    while (i < terms.items.len) : (i += 1) {
        if (terms.items[i - 100].hit)
            hits -= 1;
        for (query.items) |q| {
            if (std.mem.eql(u8, q, terms.items[i].stemmed)) {
                terms.items[i].hit = true;
                hits += 1;
                break;
            }
        }
        if (hits > max_hits) {
            max_hits = hits;
            max_hits_i = i;
        }
    }

    const end_hit = std.math.min(max_hits_i + 100, terms.items.len);

    return terms.items[max_hits_i..end_hit];
}
