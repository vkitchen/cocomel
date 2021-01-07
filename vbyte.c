/*
 * Code derived from that of libvbyte (https://github.com/cruppstahl/libvbyte).
 * Changes are predominantly:
 *   - Reformatting to match coding style of Cocomel
 *   - Removing some optimisations as to be easier to understand
 *
 * Original work Copyright (C) 2005-2016 Christoph Rupp (chris@crupp.de).
 * Modified work Copyright (C) 2018, 2019, 2021 Vaughan Kitchen
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
#include "vbyte.h"

int vbyte_read(uint8_t *in, uint32_t *out)
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
	*out = ((in[4] & 0x7Fu) << 28) | *out;
		return 5;
	}

int vbyte_store(uint8_t *p, uint32_t value)
	{
	if (value < (1u << 7))
		{
		*p = value & 0x7Fu;
		return 1;
		}
	if (value < (1u << 14))
		{
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 7;
		return 2;
		}
	if (value < (1u << 21))
		{
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 14;
		return 3;
		}
	if (value < (1u << 28))
		{
		*p = (value & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 7) & 0x7Fu) | (1u << 7);
		++p;
		*p = ((value >> 14) & 0x7Fu) | (1u << 7);
		++p;
		*p = value >> 21;
		return 4;
		}
	else
		{
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
	}
