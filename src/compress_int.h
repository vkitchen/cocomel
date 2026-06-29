#ifndef COMPRESS_INT_H
#define COMPRESS_INT_H

#include <stddef.h>
#include <stdint.h>
#include <immintrin.h>

struct pack_res {
	size_t bytes;
	size_t metadata;
};

struct compress_res {
	uint32_t blocks;
	uint32_t bytes;
};

struct pack_res compress_int_pack(__m128i *out, const uint32_t *in, uint8_t *metadata, size_t len);
size_t compress_int_unpack_d1(uint32_t *out, const __m128i *in, const uint8_t *metadata, size_t len);
struct compress_res compress_int_unpack_d1_128(uint32_t *out, const __m128i *in, const uint8_t *metadata, size_t len, uint32_t delta);

#endif
