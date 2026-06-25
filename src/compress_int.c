#include "compress_int.h"

#include "simdcomp.h"
#include "streamvbyte.h"
#include "streamvbytedelta.h"

// len = num ints
// return = num bytes
static size_t compress_int_bp128_pack(__m128i *out, const uint32_t *in, uint8_t *metadata, size_t len) {
	__m128i *p = out;

	for (const uint32_t *end = in + len; in < end; in += 128) {
		const uint8_t b = maxbits(in);
		*metadata++ = b;

		simdpackwithoutmask(in, p, b);
		p += b;
	}

	return p - out;
}

// count = num ints
// return = num bytes
static size_t compress_int_bp128_unpack_d1(uint32_t *out, const __m128i *in, const uint8_t *metadata, size_t len) {
	uint32_t delta = 0;
	const __m128i *p = in;

	for (uint32_t *end = out + len; out < end; out += 128) {
		const uint8_t b = *metadata;
		metadata++;

		simdunpackd1(delta, p, out, b);
		p += b;
		delta = out[127];
	}

	return p - in;
}


// len = num ints
// return = num bytes
struct pack_res compress_int_pack(__m128i *out, const uint32_t *in, uint8_t *metadata, size_t len) {
	size_t bp128_compressed = (len / 128) * 128;
	size_t group_varint_compressed = len - bp128_compressed;

	size_t blocks_written = compress_int_bp128_pack(out, in, metadata, bp128_compressed);
	size_t bytes_written = blocks_written * sizeof(__m128i) + streamvbyte_encode(&in[bp128_compressed], group_varint_compressed, (uint8_t *)&out[blocks_written]);

	// Zero fill remaining bytes
	uint8_t *p = (uint8_t *)out;
	while (bytes_written % 16) {
		p[bytes_written] = 0;
		bytes_written++;
	}

	return (struct pack_res){ bytes_written, len / 128 };
}

// count = num ints
// return = num bytes
size_t compress_int_unpack_d1(uint32_t *out, const __m128i *in, const uint8_t *metadata, size_t len) {
        size_t bp128_compressed = (len / 128) * 128;
	size_t group_varint_compressed = len - bp128_compressed;

	size_t blocks_read = compress_int_bp128_unpack_d1(out, in, metadata, bp128_compressed);
	size_t bytes_read = blocks_read * sizeof(__m128i);

	uint32_t delta = 0;
	if (bp128_compressed > 0)
		delta = out[bp128_compressed - 1];

	const uint8_t *p = (uint8_t *)in;
	bytes_read += streamvbyte_delta_decode(&p[bytes_read], &out[bp128_compressed], group_varint_compressed, delta);

	return (bytes_read + 15) / 16 * 16;
}
