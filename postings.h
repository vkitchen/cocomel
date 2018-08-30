#ifndef POSTINGS_H_
#define POSTINGS_H_

#include <stdint.h>

struct postings {
	size_t id;
	size_t diff;
	uint16_t count;
	size_t id_capacity;
	size_t id_length;
	uint8_t *id_store;
	size_t count_capacity;
	size_t count_length;
	uint16_t *count_store;
};

struct postings *postings_new();
void postings_append(struct postings *p, size_t id);
void postings_flush(struct postings *p);

#endif
