#ifndef COMPRESS_INT_H
#define COMPRESS_INT_H

#include <stddef.h>
#include <stdint.h>

size_t compress_int_pack(uint32_t *in, size_t len, uint8_t *out);
size_t compress_int_pack_selectors(uint32_t *in, size_t len, uint8_t *out);
size_t compress_int_unpack_d1(const uint8_t *in, const uint8_t *selectors, size_t count, uint32_t *out);

#endif
