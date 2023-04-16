//	QUERY_EXPANSION.ZIG
//	-------------------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

const dal = [_][]const u8{ "dal", "dahl", "dhal", "daal" };

fn in(haystack: []const []const u8, needle: []u8) bool {
    for (haystack) |hay| {
        if (std.mem.eql(u8, hay, needle))
            return true;
    }
    return false;
}

fn addAll(allocator: std.mem.Allocator, terms: *std.ArrayList([]u8), synonyms: []const []const u8) !void {
    for (synonyms) |unique| {
        var should_add = true;
        for (terms.items) |term| {
            if (std.mem.eql(u8, term, unique)) {
                should_add = false;
                break;
            }
        }
        if (should_add) {
            var newTerm = try allocator.alloc(u8, unique.len);
            std.mem.copy(u8, newTerm, unique);
            try terms.append(newTerm);
        }
    }
}

pub fn expandQuery(allocator: std.mem.Allocator, terms: *std.ArrayList([]u8)) !void {
    const len = terms.items.len;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const term = terms.items[i];
        if (in(&dal, term))
            try addAll(allocator, terms, &dal);
    }
}
