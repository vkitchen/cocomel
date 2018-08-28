#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "vector_kv.h"

struct vector_kv *vector_kv_new() {
	struct vector_kv *v = malloc(sizeof(struct vector_kv));
	v->capacity = 256;
	v->length = 0;
	v->items = malloc(v->capacity * 2 * sizeof(void *));
	return v;
}

void vector_kv_append(struct vector_kv *v, char *key, void *val) {
	if (v->length == v->capacity) {
		v->capacity *= 2;
		v->items = realloc(v->items, v->capacity * 2 * sizeof(void *));
	}
	v->items[v->length * 2] = key;
	v->items[v->length * 2 + 1] = val;
	v->length++;
}

void *vector_kv_find(struct vector_kv *v, char *key) {
	for (size_t i = 0; i < v->length; i++) {
		if (strcmp(key, v->items[i * 2]) == 0) {
			return v->items[i * 2 + 1];
		}
	}
	return NULL;
}

void vector_kv_sort(struct vector_kv *v) {
	for (size_t i = 1; i < v->length; i++) {
		char *tmp = v->items[i*2];
		size_t j = i;
		while (j > 0 && strcmp(tmp, v->items[(j-1)*2]) < 0) {
			v->items[j*2] = v->items[(j-1)*2];
			// TODO move val as well
			j--;
		}
		v->items[j*2] = tmp;
	}
}
