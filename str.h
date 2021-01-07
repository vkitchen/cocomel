/*
	STR.H
	-----
	Copyright (c) 2019-2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef STR_H
#define STR_H

#include <stdint.h>
#include <string.h>
#include "char_musl.h"
#include "memory.h"

#include "str_musl.h"

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

#endif

