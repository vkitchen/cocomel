/*
	DYNAMIC_ARRAY_16.H
	------------------
	Copyright (c) 2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef DYNAMIC_ARRAY_16_H
#define DYNAMIC_ARRAY_16_H

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_16
	{
	uint32_t capacity;
	uint32_t length;
	uint16_t *store;
	};

static inline void dynamic_array_16_init(struct dynamic_array_16 *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity * sizeof(uint16_t));
	}

static inline void dynamic_array_16_append(struct dynamic_array_16 *a, uint16_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity * sizeof(uint16_t));
		}
	a->store[a->length] = val;
	a->length++;
	}

static inline uint16_t *dynamic_array_16_back(struct dynamic_array_16 *a)
	{
	return &a->store[a->length-1];
	}

#endif

