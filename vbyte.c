/*
 * Copyright (C) 2005-2016 Christoph Rupp (chris@crupp.de).
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include <stdint.h>

int vbyte_read(const uint8_t *in, uint64_t *out)
{
  *out = in[0] & 0x7Fu;
  if (in[0] < 128)
    return 1;
  *out = ((in[1] & 0x7Fu) << 7) | *out;
  if (in[1] < 128)
    return 2;
  *out = ((in[2] & 0x7Fu) << 14) | *out;
  if (in[2] < 128)
    return 3;
  *out = ((in[3] & 0x7Fu) << 21) | *out;
  if (in[3] < 128)
    return 4;
  *out = ((uint64_t)(in[4] & 0x7Fu) << 28) | *out;
  if (in[4] < 128)
    return 5;
  *out = ((uint64_t)(in[5] & 0x7Fu) << 35) | *out;
  if (in[5] < 128)
    return 6;
  *out = ((uint64_t)(in[6] & 0x7Fu) << 42) | *out;
  if (in[6] < 128)
    return 7;
  *out = ((uint64_t)(in[7] & 0x7Fu) << 49) | *out;
  if (in[7] < 128)
    return 8;
  *out = ((uint64_t)(in[8] & 0x7Fu) << 56) | *out;
  if (in[8] < 128)
    return 9;
  *out = ((uint64_t)(in[9] & 0x7Fu) << 63) | *out;
  return 10;
}

int vbyte_store(uint8_t *p, uint64_t value)
{
	if (value < (1lu << 7)) {
		*p = value & 0x7Fu;
		return 1;
	}
	if (value < (1lu << 14)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 7;
		return 2;
	}
	if (value < (1lu << 21)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 14;
		return 3;
	}
	if (value < (1lu << 28)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 21;
		return 4;
	}
	if (value < (1lu << 35)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 28;
		return 5;
	}
	if (value < (1lu << 42)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 35;
		return 6;
	}
	if (value < (1lu << 49)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 35) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 42;
		return 7;
	}
	if (value < (1lu << 56)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 35) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 42) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 49;
		return 8;
	}
	if (value < (1lu << 63)) {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 35) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 42) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 49) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 56;
		return 9;
	}
	else {
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 21) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 28) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 35) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 42) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 49) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 56) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 63;
		return 10;
	}
}
