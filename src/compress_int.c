#include "compress_int.h"

#include "simdcomp.h"
#include "streamvbyte.h"
#include "streamvbytedelta.h"

// len = num ints
// return = num bytes
static size_t compress_int_bp128_pack(uint32_t *in, size_t len, uint8_t *out) {
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
static size_t compress_int_bp128_unpack(const uint8_t *in, size_t count, uint32_t *out) {
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

// len = num ints
// return = num bytes
static size_t compress_int_bp128_pack_d1(uint32_t *in, size_t len, uint8_t *out) {
	uint32_t offset = 0;
	uint8_t *p = out;

	for (uint32_t *end = in + len; in < end; in += 128) {
		const uint8_t b = simdmaxbitsd1(offset, in);
		*p++ = b;

		simdpackwithoutmaskd1(offset, in, (__m128i *)p, b);
		p += b * sizeof(__m128i);
		offset = in[127];
	}

	return p - out;
}


// count = num ints
// return = num bytes
static size_t compress_int_bp128_unpack_d1(const uint8_t *in, size_t count, uint32_t *out) {
	uint32_t offset = 0;
	const uint8_t *p = in;

	while (count > 0) {
		const uint8_t b = *p;
		p++;

		simdunpackd1(offset, p, out, b);
		p += b * sizeof(__m128i);
		out += 128;
		count -= 128;
		offset = *(out-1);
	}

	return p - in;
}

// len = num ints
// return = num bytes
size_t compress_int_pack(uint32_t *in, size_t len, uint8_t *out) {
	size_t bp128_compressed = (len / 128) * 128;
	size_t group_varint_compressed = len - bp128_compressed;

	size_t bytes_written = compress_int_bp128_pack(in, bp128_compressed, out);
	bytes_written += streamvbyte_encode(&in[bp128_compressed], group_varint_compressed, &out[bytes_written]);
	return bytes_written;
}


// count = num ints
// return = num bytes
size_t compress_int_unpack_d1(const uint8_t *in, size_t count, uint32_t *out) {
        size_t bp128_compressed = (count / 128) * 128;
	size_t group_varint_compressed = count - bp128_compressed;

	size_t bytes_read = compress_int_bp128_unpack_d1(in, bp128_compressed, out);

	uint32_t delta = 0;
	if (bp128_compressed > 0)
		delta = out[bp128_compressed - 1];

	bytes_read += streamvbyte_delta_decode(&in[bytes_read], &out[bp128_compressed], group_varint_compressed, delta);

	return bytes_read;
}
