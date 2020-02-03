#ifndef DYNAMIC_ARRAY_KV_32_H
#define DYNAMIC_ARRAY_KV_32_H

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_kv_32
	{
	uint32_t capacity;
	uint32_t length;
	uint32_t *store;
	};

static inline void dynamic_array_kv_32_init(struct dynamic_array_kv_32 *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity * sizeof(uint32_t) * 2);
	}

static inline void dynamic_array_kv_32_append(struct dynamic_array_kv_32 *a, uint32_t key, uint32_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity * sizeof(uint32_t) * 2);
		}
	a->store[a->length*2] = key;
	a->store[a->length*2+1] = val;
	a->length++;
	}

static inline uint32_t *dynamic_array_kv_32_at(struct dynamic_array_kv_32 *a, size_t i)
	{
	return &a->store[i*2];
	}

static inline uint32_t *dynamic_array_kv_32_back(struct dynamic_array_kv_32 *a)
	{
	return &a->store[a->length*2-2];
	}

#endif

