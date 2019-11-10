#pragma once

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_64
	{
	uint32_t capacity;
	uint32_t length;
	uint64_t *store;
	};

void dynamic_array_64_init(struct dynamic_array_64 *a);
void dynamic_array_64_append(struct dynamic_array_64 *a, uint64_t val);
uint64_t *dynamic_array_64_back(struct dynamic_array_64 *a);

