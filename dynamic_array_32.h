#ifndef DYNAMIC_ARRAY_32_H
#define DYNAMIC_ARRAY_32_H

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_32
	{
	uint32_t capacity;
	uint32_t length;
	uint32_t *store;
	};

static inline void dynamic_array_32_init(struct dynamic_array_32 *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity * sizeof(uint32_t));
	}

static inline void dynamic_array_32_append(struct dynamic_array_32 *a, uint32_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity * sizeof(uint32_t));
		}
	a->store[a->length] = val;
	a->length++;
	}

static inline uint32_t *dynamic_array_32_back(struct dynamic_array_32 *a)
	{
	return &a->store[a->length-1];
	}

#endif

