#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "postings.h"

struct postings *postings_new() {
	struct postings *p = malloc(sizeof(struct postings));
	p->capacity = 256;
	p->length = 0;
	p->store = malloc(p->capacity * 2 * sizeof(size_t));
	return p;
}

void postings_append(struct postings *p, size_t id) {
	/* Already exists. Increase the count */
	if (p->length > 0 && p->store[(p->length-1) * 2] == id) {
		p->store[(p->length-1) * 2 + 1]++;
//		if (p->store[(p->length-1) * 2 + 1] > 256) {
//			printf("Posting %zd has count %zd\n", p->store[(p->length-1) * 2], p->store[(p->length-1) * 2 + 1]);
//		}
		return;
	}

	if (p->length == p->capacity) {
		p->capacity *= 2;
		p->store = realloc(p->store, p->capacity * 2 * sizeof(size_t));
	}
	p->store[p->length * 2] = id;
	p->store[p->length * 2 + 1] = 1;
	p->length++;
}
