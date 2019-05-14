#ifndef POSTING_H_
#define POSTING_H_

#include <utility>
#include <stdint.h>
#include "dynamic_array.h"
#include "vector_kv.h"

struct posting {
	size_t id;
	dynamic_array<uint8_t> *ids;
	dynamic_array<uint8_t> *counts;
};

struct posting *posting_new();
void posting_append(struct posting *p, size_t id);
void posting_flush(struct posting *p);
size_t posting_write(struct posting *p, char *buffer);
dynamic_array<std::pair<size_t, double>> *posting_decompress(struct posting *posting);

#endif
