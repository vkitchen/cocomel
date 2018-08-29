#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "vector_kv.h"

struct vector_kv *vector_kv_new() {
	struct vector_kv *v = malloc(sizeof(struct vector_kv));
	v->capacity = 256;
	v->length = 0;
	v->store = malloc(v->capacity * 2 * sizeof(void *));
	return v;
}

void vector_kv_append(struct vector_kv *v, char *key, void *val) {
	if (v->length == v->capacity) {
		v->capacity *= 2;
		v->store = realloc(v->store, v->capacity * 2 * sizeof(void *));
	}
	v->store[v->length * 2] = key;
	v->store[v->length * 2 + 1] = val;
	v->length++;
}

void *vector_kv_find(struct vector_kv *v, char *key) {
	for (size_t i = 0; i < v->length; i++) {
		if (strcmp(key, v->store[i * 2]) == 0) {
			return v->store[i * 2 + 1];
		}
	}
	return NULL;
}

/* Returns reference to cell that key is stored in */
void *vector_kv_back(struct vector_kv *v) {
	if (v->length == 0) {
		return NULL;
	}
	return &v->store[(v->length-1) * 2];
}
