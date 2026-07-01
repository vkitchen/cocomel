#ifndef COMPRESS_INT_VBYTE_H
#define COMPRESS_INT_VBYTE_H

#include <stddef.h>
#include <stdint.h>
#include <immintrin.h>

#include "compress_int.h"

struct compress_res compress_int_vbyte_pack_stream(__m128i *blocks, uint8_t *bytes, const uint32_t *docs, size_t len);
struct compress_res compress_int_vbyte_unpack_block_d1(const __m128i *blocks, const uint8_t *bytes, uint32_t *docs, size_t len, uint32_t delta);

#endif
