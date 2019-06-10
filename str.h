/* ctype functions taken from musl */
/*
		STR.H
		-----
		Copyright (c) 2017 Vaughan Kitchen
		Released under the MIT license (https://opensource.org/licenses/MIT)
*/
/*!
	@file
	@brief Define a String type more useful than cstrings and helpers around that type
	@author Vaughan Kitchen
	@copyright 2017 Vaughan Kitchen
*/

#pragma once

#include <stdint.h>
#include <string.h>
#include "memory.h"

class str
	{
	private:
		char *store;

	public:
		str(char *s) : store(s) {}

		inline uint32_t length()
			{
			return *(uint32_t *)store;
			}

		inline void resize(uint32_t size)
			{
			((uint32_t *)store)[0] = size;
			}

		char &operator[](size_t index)
			{
			return store[4+index];
			}

		inline char *c_str()
			{
			return &store[4];
			}

		inline char *c_dup()
			{
			char *dest = (char *)memory_alloc(length() + 1);
			memcpy(dest, &store[4], length() + 1);
			return dest;
			}
	};


/*
	STRING_COPY()
	-------------
*/
/*!
		@brief Copies a cstring from src to dest
		@param src [in] String to copy
		@param dest [out] Buffer to copy to
		@return Number of characters copied
*/
inline size_t string_copy(char *dest, char *src)
	{
	char *at = src;
	while (*at)
		*dest++ = *at++;
	*dest = '\0';
	return at - src + 1;
	}

inline int string_prefix(const char *pre, const char *str)
	{
	while (*pre && *str)
		if (*pre++ != *str++)
			return 0;
	return 1;
	}

/* also from musl */
inline int string_cmp(const char *l, const char *r)
	{
	for (; *l == *r && *l; l++, r++)
		;
	return *(unsigned char *)l - *(unsigned char *)r;
	}

inline char char_isspace(char c)
	{
	return c == ' ' || (unsigned)c-'\t' < 5;
	}

inline char char_islower(char c)
	{
	return (unsigned)c-'a' < 26;
	}

inline char char_isupper(char c)
	{
	return (unsigned)c-'A' < 26;
	}

inline char char_isalpha(char c)
	{
	return ((unsigned)c|32)-'a' < 26;
	}

inline char char_isdigit(char c)
	{
	return (unsigned)c-'0' < 10;
	}

inline char char_tolower(char c)
	{
	if (char_isupper(c))
		return c | 32;

	return c;
	}

inline char char_toupper(char c)
	{
	if (char_islower(c))
		return c & 0x5f;
	
	return c;
	}

inline void string_tolower(char *str)
	{
	while ((*str = char_tolower(*str)))
		++str;
	}

inline void string_toupper(char *str)
	{
	while ((*str = char_toupper(*str)))
		++str;
	}
