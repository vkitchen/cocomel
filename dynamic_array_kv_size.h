/*
	DYNAMIC_ARRAY_KV_SIZE.H
	-----------------------
	Copyright (c) 2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef DYNAMIC_ARRAY_KV_SIZE_H
#define DYNAMIC_ARRAY_KV_SIZE_H

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_kv_size
	{
	uint32_t capacity;
	uint32_t length;
	size_t *store;
	};

static inline void dynamic_array_kv_size_init(struct dynamic_array_kv_size *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity * sizeof(size_t) * 2);
	}

static inline void dynamic_array_kv_size_append(struct dynamic_array_kv_size *a, size_t key, size_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity * sizeof(size_t) * 2);
		}
	a->store[a->length*2] = key;
	a->store[a->length*2+1] = val;
	a->length++;
	}

static inline size_t *dynamic_array_kv_size_at(struct dynamic_array_kv_size *a, size_t i)
	{
	return &a->store[i*2];
	}

static inline size_t *dynamic_array_kv_size_back(struct dynamic_array_kv_size *a)
	{
	return &a->store[a->length*2-2];
	}

#endif

