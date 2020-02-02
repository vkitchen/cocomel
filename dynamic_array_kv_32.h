#pragma once

#include <stdint.h>
#include <stdlib.h>

struct dynamic_array_kv_32
	{
	uint32_t capacity;
	uint32_t length;
	uint32_t *store;
	};

void dynamic_array_kv_32_init(struct dynamic_array_kv_32 *a);
void dynamic_array_kv_32_append(struct dynamic_array_kv_32 *a, uint32_t key, uint32_t val);
uint32_t *dynamic_array_kv_32_at(struct dynamic_array_kv_32 *a, size_t i);
uint32_t *dynamic_array_kv_32_back(struct dynamic_array_kv_32 *a);

