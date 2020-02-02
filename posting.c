#include <stdlib.h>
#include <string.h>
#include "vbyte.h"
#include "dynamic_array_8.h"

#include "posting.h"

void posting_init(struct posting *p)
	{
	p->id = 0;
	p->id_capacity = 256;
	p->id_length = 0;
	p->id_store = malloc(p->id_capacity);
	dynamic_array_8_init(&p->counts);
	}

void posting_append(struct posting *p, uint32_t id)
	{
	if (p->id == id)
		{
		uint8_t *count = dynamic_array_8_back(&p->counts);
		if (*count < 255)
			(*count)++;
		}
	else
		{
		if (p->id_capacity - p->id_length < 5) // Max bytes vbyte can use for 32bit int
			{
			p->id_capacity *= 2;
			p->id_store = realloc(p->id_store, p->id_capacity);
			}
		p->id_length += vbyte_store(&p->id_store[p->id_length], id - p->id);

		dynamic_array_8_append(&p->counts, 1);

		p->id = id;
		}
	}

size_t posting_write(struct posting *p, char *buffer)
	{
	size_t offset = 2 * sizeof(uint32_t);

	memcpy(&buffer[offset], p->id_store, p->id_length);
	offset += p->id_length;

	memcpy(&buffer[offset], p->counts.store, p->counts.length);
	offset += p->counts.length;

	((uint32_t *)buffer)[0] = p->id_length;
	((uint32_t *)buffer)[1] = p->counts.length;

	return offset;
	}


struct dynamic_array_kv_64 *posting_decompress(struct posting *p)
	{
	size_t id_length = ((uint32_t *)p)[0];
	size_t count_length = ((uint32_t *)p)[1];
	uint8_t *id_store = (uint8_t *)p + 2 * sizeof(uint32_t);
	uint8_t *count_store = id_store + id_length;

	struct dynamic_array_kv_64 *out = malloc(sizeof(struct dynamic_array_kv_64));
	dynamic_array_kv_64_init(out);
	size_t prevI = 0;
	uint32_t docI = 0;
	size_t di = 0;
	size_t ci = 0;
	while (ci < count_length && di < id_length)
		{
		di += vbyte_read(&id_store[di], &docI);
		docI += prevI;
		prevI = docI;
		size_t count = count_store[ci];
		dynamic_array_kv_64_append(out, docI, count);
		ci++;
		}
	return out;
	}

