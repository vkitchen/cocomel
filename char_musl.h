/*
	CHAR_MUSL.H
	-----------
	Code derived from that of the musl libc project (https://musl.libc.org/)

	Original work Copyright (c) 2005-2020 Rich Felker, et al.
	Modified work Copyright (c) 2019, 2020 Vaughan Kitchen

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

#ifndef CHAR_MUSL_H
#define CHAR_MUSL_H

static inline char char_isspace(char c)
	{
	return c == ' ' || (unsigned)c-'\t' < 5;
	}

static inline char char_islower(char c)
	{
	return (unsigned)c-'a' < 26;
	}

static inline char char_isupper(char c)
	{
	return (unsigned)c-'A' < 26;
	}

static inline char char_isalpha(char c)
	{
	return ((unsigned)c|32)-'a' < 26;
	}

static inline char char_isdigit(char c)
	{
	return (unsigned)c-'0' < 10;
	}

static inline char char_tolower(char c)
	{
	if (char_isupper(c))
		return c | 32;

	return c;
	}

static inline char char_toupper(char c)
	{
	if (char_islower(c))
		return c & 0x5f;

	return c;
	}

#endif

