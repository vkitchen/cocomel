#include "compress_int.h"

#include "simdcomp.h"
#include "streamvbyte.h"
#include "streamvbytedelta.h"

// len = num ints
// return = num bytes
static size_t compress_int_bp128_pack(uint32_t *in, size_t len, uint8_t *out, uint8_t *metadata) {
	uint8_t *p = out;

	for (uint32_t *end = in + len; in < end; in += 128) {
		const uint8_t b = maxbits(in);
		*metadata++ = b;

		simdpackwithoutmask(in, (__m128i *)p, b);
		p += b * sizeof(__m128i);
	}

	return p - out;
}

// count = num ints
// return = num bytes
static size_t compress_int_bp128_unpack_d1(const uint8_t *in, const uint8_t *selectors, size_t count, uint32_t *out) {
	uint32_t delta = 0;
	const uint8_t *p = in;

	while (count > 0) {
		const uint8_t b = *selectors;
		selectors++;

		simdunpackd1(delta, (__m128i *)p, out, b);
		p += b * sizeof(__m128i);
		out += 128;
		count -= 128;
		delta = *(out-1);
	}

	return p - in;
}

// len = num ints
// return = num bytes
struct pack_res compress_int_pack(uint32_t *in, size_t len, uint8_t *out, uint8_t *metadata) {
	size_t bp128_compressed = (len / 128) * 128;
	size_t group_varint_compressed = len - bp128_compressed;

	size_t bytes_written = compress_int_bp128_pack(in, bp128_compressed, out, metadata);
	bytes_written += streamvbyte_encode(&in[bp128_compressed], group_varint_compressed, &out[bytes_written]);

	while (bytes_written % 16) {
		out[bytes_written] = 0; // Don't fill with junk bytes
		bytes_written++;
	}

	return (struct pack_res){ bytes_written, len / 128 };
}

// count = num ints
// return = num bytes
size_t compress_int_unpack_d1(const uint8_t *in, const uint8_t *selectors, size_t count, uint32_t *out) {
        size_t bp128_compressed = (count / 128) * 128;
	size_t group_varint_compressed = count - bp128_compressed;

	size_t bytes_read = compress_int_bp128_unpack_d1(in, selectors, bp128_compressed, out);

	uint32_t delta = 0;
	if (bp128_compressed > 0)
		delta = out[bp128_compressed - 1];

	bytes_read += streamvbyte_delta_decode(&in[bytes_read], &out[bp128_compressed], group_varint_compressed, delta);

	return (bytes_read + 15) / 16 * 16;
}
