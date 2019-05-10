#ifndef POSTING_H_
#define POSTING_H_

#include <stdint.h>
#include "vector_kv.h"

struct posting {
	size_t id;
	size_t diff;
	uint8_t count;
	size_t id_capacity;
	size_t id_length;
	uint8_t *id_store;
	size_t count_capacity;
	size_t count_length;
	uint8_t *count_store;
};

struct posting *posting_new();
void posting_append(struct posting *p, size_t id);
void posting_flush(struct posting *p);
size_t posting_write(struct posting *p, char *buffer);
void posting_decode(struct posting *p);
struct vector_kv *posting_decompress(struct posting *posting);

#endif
