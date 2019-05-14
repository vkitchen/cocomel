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
	p->ids = new dynamic_array<uint8_t>();
	p->counts = new dynamic_array<uint8_t>();
	return p;
}

void posting_append(struct posting *p, size_t id) {
	if (p->id == id) {
		uint8_t *count = p->counts->back();
		if (*count < 255)
			(*count)++;
	} else {
		uint8_t buf[10];
		uint8_t *end = buf;
		end += vbyte_store(&buf[0], id - p->id);
		for (uint8_t *byte = buf; byte < end; byte++)
			p->ids->append(*byte);

		p->counts->append(1);

		p->id = id;
	}
}

size_t posting_write(struct posting *p, char *buffer) {
	size_t offset = 2 * sizeof(uint32_t);

	memcpy(&buffer[offset], p->ids->store, p->ids->length);
	offset += p->ids->length;

	memcpy(&buffer[offset], p->counts->store, p->counts->length);
	offset += p->counts->length;

	((uint32_t *)buffer)[0] = (uint32_t)p->ids->length;
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
