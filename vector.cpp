#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "vector.h"

struct vector *vector_new() {
	struct vector *v = (struct vector *)malloc(sizeof(struct vector));
	v->capacity = 256;
	v->length = 0;
	v->store = (void **)malloc(v->capacity * sizeof(void *));
	return v;
}

void vector_append(struct vector *v, void *val) {
	if (v->length == v->capacity) {
		v->capacity *= 2;
		v->store = (void **)realloc(v->store, v->capacity * sizeof(void *));
	}
	v->store[v->length] = val;
	v->length++;
}
