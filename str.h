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
		str(char *s)
			{
			store = s;
			}

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
	while (*pre)
		if (*pre++ != *str++)
			return 0;
	return 1;
	}

inline char char_lower(char c)
	{
	if (c < 'a')
		c += 'a' - 'A';

	return c;
	}

inline char char_upper(char c)
	{
	if ('Z' < c)
		c -= 'a' - 'A';
	
	return c;
	}

inline void string_lowercase(char *str)
	{
	while ((*str = char_lower(*str)))
		++str;
	}

/*
	STRING_UPPERCASE()
	------------------
*/
/*!
		@brief Inplace uppercasing of a cstring
		@param str [in,out] String to uppercase
*/
inline void string_uppercase(char *str)
	{
	while ((*str = char_upper(*str)))
		++str;
	}
