/*
	DYNAMIC_ARRAY_KV_8.H
	--------------------
	Copyright (c) 2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef DYNAMIC_ARRAY_KV_8_H
#define DYNAMIC_ARRAY_KV_8_H

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_kv_8
	{
	uint32_t capacity;
	uint32_t length;
	uint8_t *store;
	};

static inline void dynamic_array_kv_8_init(struct dynamic_array_kv_8 *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity * 2);
	}

static inline void dynamic_array_kv_8_append(struct dynamic_array_kv_8 *a, uint8_t key, uint8_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity * 2);
		}
	a->store[a->length*2] = key;
	a->store[a->length*2+1] = val;
	a->length++;
	}

static inline uint8_t *dynamic_array_kv_8_at(struct dynamic_array_kv_8 *a, size_t i)
	{
	return &a->store[i*2];
	}

static inline uint8_t *dynamic_array_kv_8_back(struct dynamic_array_kv_8 *a)
	{
	return &a->store[a->length*2-2];
	}

#endif

