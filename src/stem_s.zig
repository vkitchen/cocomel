//	STEM_S.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

const std = @import("std");

pub fn stem(term: []u8) []u8 {
    if (std.mem.endsWith(u8, term, "ies")) {
        term[term.len - 3] = 'y';
        return term[0 .. term.len - 2];
    } else if (std.mem.endsWith(u8, term, "es")) {
        return term[0 .. term.len - 2];
    } else if (std.mem.endsWith(u8, term, "s"))
        return term[0 .. term.len - 1];

    return term;
}

test "s stripping stemmer" {
    var buffer: [100]u8 = undefined;

    const cookies = "cookies";
    std.mem.copy(u8, &buffer, cookies);
    try std.testing.expect(std.mem.eql(u8, stem(buffer[0..cookies.len]), "cooky"));

    const scapes = "garlic scapes";
    std.mem.copy(u8, &buffer, scapes);
    try std.testing.expect(std.mem.eql(u8, stem(buffer[0..scapes.len]), "garlic scap"));

    const biscuits = "biscuits";
    std.mem.copy(u8, &buffer, biscuits);
    try std.testing.expect(std.mem.eql(u8, stem(buffer[0..biscuits.len]), "biscuit"));
}
