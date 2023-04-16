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
