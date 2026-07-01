#include "compress_int_vbyte.h"

#include "varintencode.h"
#include "varintdecode.h"

struct compress_res compress_int_vbyte_pack_stream(__m128i *blocks, uint8_t *bytes, const uint32_t *docs, size_t len) {
	size_t bytes_written = vbyte_encode(docs, len, bytes);

	return (struct compress_res){ 0, bytes_written };
}

struct compress_res compress_int_vbyte_unpack_block_d1(const __m128i *blocks, const uint8_t *bytes, uint32_t *docs, size_t len, uint32_t delta) {
	size_t bytes_read = masked_vbyte_decode_delta(bytes, docs, len, delta);

	return (struct compress_res){ 0, bytes_read };
}
