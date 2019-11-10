#include <stdint.h>
#include <stdlib.h>
#include "memory.h"

#include "dynamic_array_64.h"

void dynamic_array_64_init(struct dynamic_array_64 *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity * sizeof(uint64_t));
	}

void dynamic_array_64_append(struct dynamic_array_64 *a, uint64_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity * sizeof(uint64_t));
		}
	a->store[a->length] = val;
	a->length++;
	}

uint64_t *dynamic_array_64_back(struct dynamic_array_64 *a)
	{
	return &a->store[a->length-1];
	}

