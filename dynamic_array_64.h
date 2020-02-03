#ifndef DYNAMIC_ARRAY_64_H
#define DYNAMIC_ARRAY_64_H

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_64
	{
	uint32_t capacity;
	uint32_t length;
	uint64_t *store;
	};

static inline void dynamic_array_64_init(struct dynamic_array_64 *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity * sizeof(uint64_t));
	}

static inline void dynamic_array_64_append(struct dynamic_array_64 *a, uint64_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity * sizeof(uint64_t));
		}
	a->store[a->length] = val;
	a->length++;
	}

static inline uint64_t *dynamic_array_64_back(struct dynamic_array_64 *a)
	{
	return &a->store[a->length-1];
	}

#endif

