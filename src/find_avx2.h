// Copyright (c) Vaughan Kitchen
// Released under the ISC license (https://opensource.org/license/isc)

#ifndef FIND_AVX2_H
#define FIND_AVX2_H

#include <stddef.h>
#include <stdint.h>

int find_avx2(uint32_t *haystack, size_t len, uint32_t needle);

#endif
