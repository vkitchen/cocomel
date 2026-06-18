#include "compress_int_bp128.h"

#include "simdcomp.h"

// len = num ints
// return = num bytes
size_t compress_int_bp128_pack(uint32_t *in, size_t len, uint8_t *out) {
	uint8_t *p = out;

	for (uint32_t *end = in + len; in < end; in += 128) {
		const uint8_t b = maxbits(in);
		*p++ = b;

		simdpackwithoutmask(in, (__m128i *)p, b);
		p += b * sizeof(__m128i);
	}

	return p - out;
}

// count = num ints
// return = num bytes
size_t compress_int_bp128_unpack(const uint8_t *in, size_t count, uint32_t *out) {
	const uint8_t *p = in;

	while (count > 0) {
		const uint8_t b = *p;
		p++;

		simdunpack(p, out, b);
		p += b * sizeof(__m128i);
		out += 128;
		count -= 128;
	}

	return p - in;
}
