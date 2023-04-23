//	SNIPPETS.ZIG
//	------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Tokenizer = @import("tokenizer_snippet.zig").Tokenizer;
const Term = @import("tokenizer_snippet.zig").Term;

pub const Snippeter = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    snippets: []const u8,
    terms: std.ArrayListUnmanaged(Term),

    pub fn init(allocator: std.mem.Allocator, snippets: []const u8, terms: std.ArrayListUnmanaged(Term)) !Self {
        return .{
            .allocator = allocator,
            .snippets = snippets,
            .terms = terms,
        };
    }

    pub fn snippet(self: *Self, query: [][]u8, start: usize, end: usize) ![]Term {
        self.terms.clearRetainingCapacity();

        var toker = Tokenizer.init(self.snippets, start, end);
        try toker.tokenize(self.allocator, &self.terms);

        const window = std.math.min(100, self.terms.items.len);
        if (window < 100)
            return self.terms.items;

        var hits: usize = 0;
        var max_hits: usize = 0;
        var max_hits_i: usize = 0;
        var i: usize = 0;
        while (i < window) : (i += 1) {
            for (query) |q| {
                if (std.mem.eql(u8, q, self.terms.items[i].stemmed)) {
                    self.terms.items[i].hit = true;
                    hits += 1;
                    break;
                }
            }
        }
        max_hits = hits;

        while (i < self.terms.items.len) : (i += 1) {
            if (self.terms.items[i - 100].hit)
                hits -= 1;
            for (query) |q| {
                if (std.mem.eql(u8, q, self.terms.items[i].stemmed)) {
                    self.terms.items[i].hit = true;
                    hits += 1;
                    break;
                }
            }
            if (hits > max_hits) {
                max_hits = hits;
                max_hits_i = i;
            }
        }

        const end_hit = std.math.min(max_hits_i + 100, self.terms.items.len);

        return self.terms.items[max_hits_i..end_hit];
    }
};
