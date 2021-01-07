/*
	STR_MUSL.H
	----------
	Code derived from that of the musl libc project (https://musl.libc.org/)

	Original work Copyright (c) 2005-2020 Rich Felker, et al.
	Modified work Copyright (c) 2020 Vaughan Kitchen

	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#ifndef STR_MUSL_H
#define STR_MUSL_H

#include <stdint.h>
#include <string.h>
#include "char_musl.h"
#include "memory.h"

static inline int string_cmp(const char *l, const char *r)
	{
	for (; *l == *r && *l; l++, r++)
		;
	return *(unsigned char *)l - *(unsigned char *)r;
	}


static inline void string_tolower(char *str)
	{
	while ((*str = char_tolower(*str)))
		++str;
	}

static inline void string_toupper(char *str)
	{
	while ((*str = char_toupper(*str)))
		++str;
	}

#endif

