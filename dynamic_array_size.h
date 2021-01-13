/*
	DYNAMIC_ARRAY_SIZE.H
	--------------------
	Copyright (c) 2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef DYNAMIC_ARRAY_SIZE_H
#define DYNAMIC_ARRAY_SIZE_H

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_size
	{
	uint32_t capacity;
	uint32_t length;
	size_t *store;
	};

static inline void dynamic_array_size_init(struct dynamic_array_size *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity * sizeof(size_t));
	}

static inline void dynamic_array_size_append(struct dynamic_array_size *a, size_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity * sizeof(size_t));
		}
	a->store[a->length] = val;
	a->length++;
	}

static inline size_t *dynamic_array_size_back(struct dynamic_array_size *a)
	{
	return &a->store[a->length-1];
	}

#endif

