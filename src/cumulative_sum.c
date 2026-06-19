/*
 * Copyright (c) Andrew Trotman
 * Released under the 2-clause BSD license (See:https://en.wikipedia.org/wiki/BSD_licenses)
 */

#include "cumulative_sum.h"

#include <immintrin.h>

// Stolen from JASSv2 https://github.com/andrewtrotman/JASSv2/blob/master/source/simd.h
// Modified to not overread
void cumulative_sum(uint32_t *data, size_t len) {
	size_t len_8 = (len / 8) * 8;

	/*
		previous cumulative sum is zero
	*/
	__m256i previous_max = _mm256_setzero_si256();

	/*
		Loop over the data in blocks of 8
	*/
	__m256i *end = (__m256i *)(data + len_8);
	for (__m256i *block = (__m256i *)data; block < end; block++) {
		/*
			load the next 8 integers
		*/
		__m256i current_set = _mm256_lddqu_si256(block);

		/*
			shift left by 1 integer and add
			A B C D E F G H
			B C D 0 F G H 0
		*/
		__m256i bottom = _mm256_bslli_epi128(current_set, 4);
		current_set = _mm256_add_epi32(current_set, bottom);

		/*
			shift left by 2 integers and add
			AB BC CD D0 EF FG GH H0
			CD D0 00 00 GH H0 00 00
		*/
		bottom = _mm256_bslli_epi128(current_set, 8);
		current_set = _mm256_add_epi32(current_set, bottom);
		/*
			We have: ABCD BCD0 CD00 D000 EFGH FGH0 GH00 H0000
		*/

		/*
			shuffle to get: 0000 0000 0000 0000 EFGH EFGH EFGH EFGH
			permute to get: EFGH EFGH EFGH EFGH 0000 0000 0000 0000
		*/
		__m256i missing = _mm256_shuffle_epi32(current_set, _MM_SHUFFLE(3, 3, 3, 3));
		missing = _mm256_permute2x128_si256(_mm256_setzero_si256(), missing, 2 << 4);

		/*
			ABCD BCD0 CD00 D000 EFGH FGH0 GH00 H000
			EFGH EFGH EFGH EFGH 0000 0000 0000 0000
		*/
		current_set = _mm256_add_epi32(current_set, missing);

		/*
			add the previous maximum to each of them
		*/
		current_set = _mm256_add_epi32(current_set, previous_max);

		/*
			and write back out to the same location we read from
		*/
		_mm256_storeu_si256(block, current_set);

		/*
			Broadcast the largest number from the result for next time
		*/
		current_set = _mm256_shuffle_epi32(current_set, _MM_SHUFFLE(3, 3, 3, 3));
		previous_max = _mm256_permute2x128_si256(current_set, current_set, 3 | (3 << 4));
	}

	/*
		Process remaining
	*/
	uint32_t prev = 0;
	if (len_8 > 0) prev = data[len_8 - 1];
	for (size_t i = len_8; i < len; i++) {
		data[i] += prev;
		prev = data[i];
	}
}
