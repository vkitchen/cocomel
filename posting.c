#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "vbyte.h"
#include "posting.h"

struct posting *posting_new() {
	struct posting *p = malloc(sizeof(struct posting));
	p->id = 0;
	p->count = 0;
	p->id_capacity = 256;
	p->id_length = 0;
	p->id_store = malloc(p->id_capacity * sizeof(uint8_t));
	p->count_capacity = 256;
	p->count_length = 0;
	p->count_store = malloc(p->count_capacity * sizeof(uint8_t));
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
		p->id_store = realloc(p->id_store, p->id_capacity * sizeof(uint8_t));
	}
	p->id_length += vbyte_store(&p->id_store[p->id_length], p->diff);

	if (p->count_length == p->count_capacity) {
		p->count_capacity *= 2;
		p->count_store = realloc(p->count_store, p->count_capacity * sizeof(uint8_t));
	}
	p->count_store[p->count_length] = p->count;
	p->count_length++;
}
