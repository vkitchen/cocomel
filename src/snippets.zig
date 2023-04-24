//	SNIPPETS.ZIG
//	------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");
const Tokenizer = @import("tokenizer_snippet.zig").Tokenizer;
const Term = @import("tokenizer_snippet.zig").Term;

const window_size = 100;

pub const Snippeter = struct {
    const Self = @This();

    allocator: std.heap.FixedBufferAllocator,
    snippets: []const u8,
    terms: std.ArrayListUnmanaged(Term),

    pub fn init(allocator: std.heap.FixedBufferAllocator, snippets: []const u8, terms: std.ArrayListUnmanaged(Term)) !Self {
        return .{
            .allocator = allocator,
            .snippets = snippets,
            .terms = terms,
        };
    }

    pub fn snippet(self: *Self, query: [][]u8, start: usize, end: usize) ![]Term {
        self.terms.clearRetainingCapacity();
        self.allocator.reset();

        var toker = Tokenizer.init(self.snippets, start, end);
        try toker.tokenize(self.allocator.allocator(), &self.terms);

        var hits: usize = 0;
        var max_hits: usize = 0;
        var max_hits_i: usize = 0;
        var i: usize = 0;
        while (i < self.terms.items.len) : (i += 1) {
            for (query) |q| {
                if (std.mem.eql(u8, q, self.terms.items[i].stemmed)) {
                    self.terms.items[i].hit = true;
                    if (i < window_size)
                        hits += 1;
                    break;
                }
            }
        }
        max_hits = hits;

        if (self.terms.items.len < window_size)
            return self.terms.items;

        i = window_size;
        while (i < self.terms.items.len) : (i += 1) {
            if (self.terms.items[i].hit)
                hits += 1;
            // TODO check the math
            if (self.terms.items[i - window_size].hit)
                hits -= 1;
            if (hits > max_hits) {
                max_hits = hits;
                max_hits_i = i;
            }
        }

        const end_hit = std.math.min(max_hits_i + window_size, self.terms.items.len);

        return self.terms.items[max_hits_i..end_hit];
    }
};
