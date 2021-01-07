/*
	STR.H
	-----
	Copyright (c) 2019-2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef STR_H
#define STR_H

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "char_musl.h"
#include "memory.h"

#include "str_musl.h"

static inline size_t string_copy(char *dest, char *src);

struct str
	{
	char *store;
	};

static inline uint32_t str_cap(struct str s)
	{
	return ((uint32_t *)s.store)[0];
	}

static inline uint32_t str_len(struct str s)
	{
	return ((uint32_t *)s.store)[1];
	}

static inline void str_resize(struct str s, uint32_t size)
	{
	((uint32_t *)s.store)[1] = size;
	}

static inline char *str_c(struct str s)
	{
	return &s.store[2 * sizeof(uint32_t)];
	}

static inline char *str_dup_c(struct str s)
	{
	uint32_t len = str_len(s);
	char *dest = memory_alloc(len + 1);
	memcpy(dest, str_c(s), len + 1);
	return dest;
	}

/* XXX requires an allocater with realloc if going to append */
static inline struct str str_new(uint32_t cap)
	{
	struct str res;
	res.store = malloc(cap + 1 + 2 * sizeof(uint32_t));
	if (res.store == NULL)
		{
		fprintf(stderr, "ERROR: Unable to alloc str of size %d bytes\n", cap);
		exit(1);
		}
	((uint32_t *)res.store)[0] = cap;
	((uint32_t *)res.store)[1] = 0;
	return res;
	}

static inline struct str str_append(struct str dest, struct str src)
	{
	// printf("%d %d %d\n", str_cap(dest), str_len(dest), str_len(src));
	// TODO replace with MAX()
	while (str_len(dest) + str_len(src) > str_cap(dest))
		{
		dest.store = realloc(dest.store, 2 * str_cap(dest) + 1 + 2 * sizeof(uint32_t));
		// TODO make into library
		if (dest.store == NULL)
			{
			fprintf(stderr, "ERROR: Unable to realloc str to be %d bytes\n", str_cap(dest) * 2);
			exit(1);
			}
		((uint32_t *)dest.store)[0] = str_cap(dest) * 2;
		}
	string_copy(str_c(dest) + str_len(dest), str_c(src));
	((uint32_t *)dest.store)[1] += str_len(src);

	return dest;
	}

static inline struct str str_append_c(struct str dest, char *src)
	{
	// printf("%d %d %d\n", str_cap(dest), str_len(dest), strlen(src));
	// TODO replace with MAX()
	while (str_len(dest) + strlen(src) > str_cap(dest))
		{
		dest.store = realloc(dest.store, 2 * str_cap(dest) + 1 + 2 * sizeof(uint32_t));
		// TODO make into library
		if (dest.store == NULL)
			{
			fprintf(stderr, "ERROR: Unable to realloc str to be %d bytes\n", str_cap(dest) * 2);
			exit(1);
			}
		((uint32_t *)dest.store)[0] = str_cap(dest) * 2;
		}
	string_copy(str_c(dest) + str_len(dest), src);
	((uint32_t *)dest.store)[1] += strlen(src);

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

