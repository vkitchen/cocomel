#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "posting.h"

struct posting *posting_new() {
	struct posting *p = malloc(sizeof(struct posting));
	p->capacity = 256;
	p->length = 0;
	p->store = malloc(p->capacity * 2 * sizeof(size_t));
	return p;
}

void posting_append(struct posting *p, size_t id) {
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
