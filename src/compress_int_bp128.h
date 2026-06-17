#ifndef COMPRESS_INT_BP128_H
#define COMPRESS_INT_BP128_H

#include <stddef.h>
#include <stdint.h>

size_t compress_int_bp128_pack(uint32_t *in, size_t len, uint8_t *out);
size_t compress_int_bp128_unpack(const uint8_t *in, size_t count, uint32_t *out);

#endif
