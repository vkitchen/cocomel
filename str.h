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

#ifndef STR_H
#define STR_H

#include <stdint.h>
#include <string.h>
#include "char.h"
#include "memory.h"

struct str
	{
	char *store;
	};

static inline uint32_t str_length(struct str s)
	{
	return *(uint32_t *)s.store;
	}

static inline void str_resize(struct str s, uint32_t size)
	{
	((uint32_t *)s.store)[0] = size;
	}

static inline char *str_c(struct str s)
	{
	return &s.store[4];
	}

static inline char *str_dup_c(struct str s)
	{
	uint32_t len = str_length(s);
	char *dest = memory_alloc(len + 1);
	memcpy(dest, &s.store[4], len + 1);
	return dest;
	}

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
static inline size_t string_copy(char *dest, char *src)
	{
	char *at = src;
	while (*at)
		*dest++ = *at++;
	*dest = '\0';
	return at - src + 1;
	}

/*
	Takes buffer size (including terminating null-byte)
	Returns new string size not including null-byte
*/
static inline size_t string_n_copy(char *dest, char *src, size_t n)
	{
	char *at = src;
	while (*at && (size_t)(at - src) < n - 1)
		*dest++ = *at++;
	*dest = '\0';
	return at - src;
	}

static inline int string_prefix(const char *pre, const char *str)
	{
	while (*pre && *str)
		if (*pre++ != *str++)
			return 0;
	return 1;
	}

static inline int string_suffix(const char *suf, const char *str)
	{
	size_t suf_len = strlen(suf);
	size_t str_len = strlen(str);
	if (suf_len > str_len)
		return 0;
	for (size_t i = 0; i < suf_len; i++)
		if (str[i + (str_len - suf_len)] != suf[i])
			return 0;
	return 1;
	}

/* also from musl */
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

