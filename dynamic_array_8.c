#include <stdint.h>
#include <stdlib.h>
#include "memory.h"

#include "dynamic_array_8.h"

void dynamic_array_8_init(struct dynamic_array_8 *a)
	{
	a->capacity = 256;
	a->length = 0;
	a->store = malloc(a->capacity);
	}

void dynamic_array_8_append(struct dynamic_array_8 *a, uint8_t val)
	{
	if (a->length == a->capacity)
		{
		a->capacity *= 2;
		a->store = realloc(a->store, a->capacity);
		}
	a->store[a->length] = val;
	a->length++;
	}

uint8_t *dynamic_array_8_back(struct dynamic_array_8 *a)
	{
	return &a->store[a->length-1];
	}

