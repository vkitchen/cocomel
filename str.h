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

struct str
	{
	char *store;
	};

uint32_t str_length(struct str s);
void str_resize(struct str s, uint32_t size);
char *str_c(struct str s);
char *str_dup_c(struct str s);

size_t string_copy(char *dest, char *src);
size_t string_n_copy(char *dest, char *src, size_t n);
int string_prefix(const char *pre, const char *str);
int string_suffix(const char *suf, const char *str);
int string_cmp(const char *l, const char *r);
void string_tolower(char *str);
void string_toupper(char *str);

