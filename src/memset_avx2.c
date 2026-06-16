#include <immintrin.h>

#include "memset_avx2.h"

void memset_avx2(unsigned char *dest, size_t len) {
	__m256i v = _mm256_setzero_si256();

	// TODO I'm not convinced this unrolling helps
	while (len >= 256) {
		_mm256_stream_si256((__m256i*)(dest +   0), v);
		_mm256_stream_si256((__m256i*)(dest +  32), v);
		_mm256_stream_si256((__m256i*)(dest +  64), v);
		_mm256_stream_si256((__m256i*)(dest +  96), v);
		_mm256_stream_si256((__m256i*)(dest + 128), v);
		_mm256_stream_si256((__m256i*)(dest + 160), v);
		_mm256_stream_si256((__m256i*)(dest + 192), v);
		_mm256_stream_si256((__m256i*)(dest + 224), v);

		dest += 256;
		len -= 256;
	}

	while (len >= 32) {
		_mm256_stream_si256((__m256i*)dest, v);
		dest += 32;
		len -= 32;
	}

	_mm_sfence();

	while (len) {
		*dest++ = 0;
		--len;
	}
}
