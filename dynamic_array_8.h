#ifndef DYNAMIC_ARRAY_8_H
#define DYNAMIC_ARRAY_8_H

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_8
	{
	uint32_t capacity;
	uint32_t length;
	uint8_t *store;
	};

void dynamic_array_8_init(struct dynamic_array_8 *a);
void dynamic_array_8_append(struct dynamic_array_8 *a, uint8_t val);
uint8_t *dynamic_array_8_back(struct dynamic_array_8 *a);

#endif

