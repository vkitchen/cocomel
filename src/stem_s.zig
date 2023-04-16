//	STEM_S.ZIG
//	----------
//	Copyright (c) Vaughan Kitchen
//	Released under the ISC license (https://opensource.org/licenses/ISC)

pub fn stem(term: []u8) []u8 {
    const end = term.len - 1;

    if (term.len > 3 and term[end - 2] == 'i' and term[end - 1] == 'e' and term[end] == 's') {
        term[end - 2] = 'y';
        return term[0 .. end - 1];
    } else if (term.len > 2 and term[end - 1] == 'e' and term[end] == 's') {
        return term[0 .. end - 1];
    } else if (term.len > 1 and term[end] == 's')
        return term[0..end];

    return term;
}

test "s stripping stemmer" {
    const std = @import("std");

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
