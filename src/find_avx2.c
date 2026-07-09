// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

#include "find_avx2.h"

#include <immintrin.h>

int find_avx2(uint32_t *haystack, size_t len, uint32_t needle) {
	size_t i = 0;

	__m256i needle_vec = _mm256_set1_epi32(needle);

	for (; i + 8 <= len; i += 8) {
		__m256i haystack_vec = _mm256_loadu_si256((int *)&haystack[i]);

		__m256i mask = _mm256_cmpeq_epi32(haystack_vec, needle_vec);

		int bitmask = _mm256_movemask_epi8(mask);

		if (bitmask != 0) {
			int byte_offset = __builtin_ctz(bitmask);

			return i + byte_offset / sizeof(uint32_t);
		}
	}

	for (; i < len; ++i) {
		if (haystack[i] == needle) {
			return i;
		}
	}

	return -1;
}
