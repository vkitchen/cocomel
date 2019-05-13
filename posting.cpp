#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "vbyte.h"
#include "vector_kv.h"
#include "posting.h"

struct posting *posting_new() {
	struct posting *p = (struct posting *)malloc(sizeof(struct posting));
	p->id = 0;
	p->count = 0;
	p->id_capacity = 256;
	p->id_length = 0;
	p->id_store = (uint8_t *)malloc(p->id_capacity * sizeof(uint8_t));
	p->count_capacity = 256;
	p->count_length = 0;
	p->count_store = (uint8_t *)malloc(p->count_capacity * sizeof(uint8_t));
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

	if (p->count_length == p->count_capacity) {
		p->count_capacity *= 2;
		p->count_store = (uint8_t *)realloc(p->count_store, p->count_capacity * sizeof(uint8_t));
	}
	p->count_store[p->count_length] = p->count;
	p->count_length++;
}

size_t posting_write(struct posting *p, char *buffer) {
	size_t offset = sizeof(struct posting);

	posting_flush(p);

	memcpy(&buffer[offset], p->id_store, p->id_length);
	p->id_store = (uint8_t *)offset;
	offset += p->id_length;

	memcpy(&buffer[offset], p->count_store, p->count_length);
	p->count_store = (uint8_t *)offset;
	offset += p->count_length;

	memcpy(&buffer[0], p, sizeof(struct posting));

	return offset;
}

void posting_decode(struct posting *p) {
	p->id_store = (uint8_t *)p + (size_t)p->id_store;
	p->count_store = (uint8_t *)p + (size_t)p->count_store;
}

struct vector_kv *posting_decompress(struct posting *posting) {
	struct vector_kv *out = vector_kv_new();
	size_t prevI = 0;
	uint64_t docI = 0;
	size_t di = 0;
	size_t ci = 0;
	while (ci < posting->count_length && di < posting->id_length) {
		di += vbyte_read(&posting->id_store[di], &docI);
		docI += prevI;
		prevI = docI;
		size_t count = posting->count_store[ci];
		vector_kv_append(out, (char *)docI, (void *)count);
		ci++;
	}
	return out;
}
