// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

#include "compress_int_bp128.h"

#include "simdcomp.h"
#include "varintencode.h"
#include "varintdecode.h"

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
	size_t remainder = len - bp128_compressed;

	size_t blocks_written = bp128_pack_stream(blocks, bytes, docs, bp128_compressed);
	size_t bytes_written = len / 128; // selectors

	// Zero terminate selectors
	bytes[bytes_written] = 0;
	bytes_written++;

	// Encode the tail length into the selector
	bytes_written += vbyte_encode(&remainder, 1, &bytes[bytes_written]);

	// Compress the tail
	bytes_written += vbyte_encode(&docs[bp128_compressed], remainder, &bytes[bytes_written]);

	return (struct compress_res){ blocks_written, bytes_written };
}

struct compress_res compress_int_bp128_unpack_block(const __m128i *blocks, const uint8_t *bytes, uint32_t *docs) {
	const uint8_t b = *bytes;
	if (b != 0) {
		simdunpack(blocks, docs, b);
		return (struct compress_res){ b, 1 };
	} else {
		size_t bytes_read = 1;
		uint32_t len;

		bytes_read += masked_vbyte_decode(&bytes[bytes_read], &len, 1);
		bytes_read += masked_vbyte_decode(&bytes[bytes_read], docs, len);
		return (struct compress_res){ 0, bytes_read };
	}
}
