#include "compress_int_bp128.h"

#include "simdcomp.h"
#include "streamvbyte.h"
#include "streamvbytedelta.h"

static size_t bp128_pack_stream(__m128i *blocks, uint8_t *bytes, const uint32_t *docs, size_t len) {
	__m128i *p = blocks;

	for (const uint32_t *end = docs + len; docs < end; docs += 128) {
		const uint8_t b = maxbits(docs);
		*bytes++ = b;

		simdpackwithoutmask(docs, p, b);
		p += b;
	}

	return p - blocks;
}

struct compress_res compress_int_bp128_pack_stream(__m128i *blocks, uint8_t *bytes, const uint32_t *docs, size_t len) {
	size_t bp128_compressed = (len / 128) * 128;
	size_t group_varint_compressed = len - bp128_compressed;

	size_t blocks_written = bp128_pack_stream(blocks, bytes, docs, bp128_compressed);
	size_t bytes_written = blocks_written * sizeof(__m128i) + streamvbyte_encode(&docs[bp128_compressed], group_varint_compressed, (uint8_t *)&blocks[blocks_written]);

	// Zero fill remaining bytes
	uint8_t *p = (uint8_t *)blocks;
	while (bytes_written % 16) {
		p[bytes_written] = 0;
		bytes_written++;
	}

	return (struct compress_res){ bytes_written / 16, len / 128 };
}

struct compress_res compress_int_bp128_unpack_block_d1(const __m128i *blocks, const uint8_t *bytes, uint32_t *docs, size_t len, uint32_t delta) {
	if (len == 128) {
		const uint8_t b = *bytes;
		simdunpackd1(delta, blocks, docs, b);
		return (struct compress_res){ b, 1 };
	} else {
		size_t bytes_read = streamvbyte_delta_decode(blocks, docs, len, delta);
		return (struct compress_res){ (bytes_read + 15) / 16, 0 };
	}
}
