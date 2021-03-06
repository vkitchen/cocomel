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

#ifndef VBYTE_H
#define VBYTE_H

#include <stdint.h>

int vbyte_read(uint8_t *p, uint32_t *out);
int vbyte_store(uint8_t *p, uint32_t value);

#endif

