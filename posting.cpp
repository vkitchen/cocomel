#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <utility>
#include "vbyte.h"
#include "vector_kv.h"
#include "dynamic_array.h"
#include "posting.h"

struct posting *posting_new() {
	struct posting *p = (struct posting *)memory_alloc(sizeof(struct posting));
	p->id = 0;
	p->count = 0;
	p->id_capacity = 256;
	p->id_length = 0;
	p->id_store = (uint8_t *)malloc(p->id_capacity * sizeof(uint8_t));
	p->counts = new dynamic_array<uint8_t>();
	return p;
}

void posting_append(struct posting *p, size_t id) {
	if (p->count == 0) {
		p->id = id;
		p->diff = id;
		p->count = 1;
		return;
	}
	/* Already exists. Increase the count */
	if (p->id == id) {
		if (p->count == 255) {
			return;
		}
		p->count++;
		return;
	}

	posting_flush(p);
	p->diff = id - p->id;
	p->id = id;
	p->count = 1;
}

void posting_flush(struct posting *p) {
	if (p->id_capacity - p->id_length < 16) {
		p->id_capacity *= 2;
		p->id_store = (uint8_t *)realloc(p->id_store, p->id_capacity * sizeof(uint8_t));
	}
	p->id_length += vbyte_store(&p->id_store[p->id_length], p->diff);

	p->counts->append(p->count);
}

size_t posting_write(struct posting *p, char *buffer) {
	size_t offset = 2 * sizeof(uint32_t);

	posting_flush(p);

	memcpy(&buffer[offset], p->id_store, p->id_length);
	offset += p->id_length;

	memcpy(&buffer[offset], p->counts->store, p->counts->length);
	offset += p->counts->length;

	((uint32_t *)buffer)[0] = (uint32_t)p->id_length;
	((uint32_t *)buffer)[1] = (uint32_t)p->counts->length;

	return offset;
}


dynamic_array<std::pair<size_t, double>> *posting_decompress(struct posting *p) {
	size_t id_length = ((uint32_t *)p)[0];
	size_t count_length = ((uint32_t *)p)[1];
	uint8_t *id_store = (uint8_t *)p + 2 * sizeof(uint32_t);
	uint8_t *count_store = id_store + id_length;

	dynamic_array<std::pair<size_t, double>> *out = new dynamic_array<std::pair<size_t, double>>;
	size_t prevI = 0;
	uint64_t docI = 0;
	size_t di = 0;
	size_t ci = 0;
	while (ci < count_length && di < id_length) {
		di += vbyte_read(&id_store[di], &docI);
		docI += prevI;
		prevI = docI;
		size_t count = count_store[ci];
		out->append(std::make_pair(docI, count));
		ci++;
	}
	return out;
}
