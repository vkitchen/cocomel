/*
	DYNAMIC_ARRAY_KV_64.H
	---------------------
	Copyright (c) 2019-2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef DYNAMIC_ARRAY_KV_64_H
#define DYNAMIC_ARRAY_KV_64_H

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_kv_64
	{
	uint32_t capacity;
	uint32_t length;
	uint64_t *store;
	};

static inline void dynamic_array_kv_64_init(struct dynamic_array_kv_64 *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity * sizeof(uint64_t) * 2);
	}

static inline void dynamic_array_kv_64_append(struct dynamic_array_kv_64 *a, uint64_t key, uint64_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity * sizeof(uint64_t) * 2);
		}
	a->store[a->length*2] = key;
	a->store[a->length*2+1] = val;
	a->length++;
	}

static inline uint64_t *dynamic_array_kv_64_at(struct dynamic_array_kv_64 *a, size_t i)
	{
	return &a->store[i*2];
	}

static inline uint64_t *dynamic_array_kv_64_back(struct dynamic_array_kv_64 *a)
	{
	return &a->store[a->length*2-2];
	}

#endif

