#ifndef POSTING_H
#define POSTING_H

#include <stdint.h>
#include "dynamic_array_8.h"
#include "dynamic_array_kv_64.h"

struct posting
	{
	uint32_t id;
	uint32_t id_capacity;
	uint32_t id_length;
	uint8_t *id_store;
	struct dynamic_array_8 counts;
	};

void posting_init(struct posting *p);
void posting_append(struct posting *p, uint32_t id);
size_t posting_write(struct posting *p, char *buffer);
struct dynamic_array_kv_64 *posting_decompress(struct posting *p);

#endif

