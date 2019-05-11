#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "string2.h"
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
void **vector_kv_back(struct vector_kv *v) {
	if (v->length == 0) {
		return NULL;
	}
	return &v->store[(v->length-1) * 2];
}

size_t vector_kv_write(struct vector_kv *v, char *buffer) {
	size_t offset = sizeof(struct vector_kv) + sizeof(size_t) * v->length * 2;

	for (size_t i = 0; i < v->length; i++) {
		size_t delta = string_copy_c(&buffer[offset], v->store[i * 2]);
		v->store[i * 2] = (void *)offset;
		offset += delta;
	}
	memcpy(buffer + sizeof(struct vector_kv), v->store, sizeof(size_t) * v->length * 2);
	v->store = (void **)(sizeof(struct vector_kv) / sizeof(size_t));
	memcpy(&buffer[0], v, sizeof(struct vector_kv));

	return offset;
}

void vector_kv_decode(struct vector_kv *v) {
	v->store = (void **)v + (size_t)v->store;
	for (size_t i = 0; i < v->length; i++) {
		v->store[i * 2] = (void *)v + (size_t)v->store[i * 2];
	}
}

struct vector_kv *vector_kv_intersect(struct vector_kv *a, struct vector_kv *b) {
	double *weights;
	size_t wi = 0;

	struct vector_kv *out = vector_kv_new();
	if (a->length == 0 || b->length == 0) {
		return out;
	}
	if (a->length > b->length) {
		weights = malloc(sizeof(double) * a->length);
	} else {
		weights = malloc(sizeof(double) * b->length);
	}
	
	for (;;) {
		if (a->length == 0 || b->length == 0) {
			goto done;
		}
		if (a->store[0] == b->store[0]) {
			double weight = *(double *)a->store[1] + *(double *)b->store[1];
			weights[wi] = weight;
			wi++;

			vector_kv_append(out, a->store[0], &weights[wi-1]);
			a->length--;
			a->store += 2;
			b->length--;
			b->store += 2;
			continue;
		}
		while (a->length > 0 && b->length > 0 && a->store[0] < b->store[0]) {
			a->length--;
			a->store += 2;
		}
		while (a->length > 0 && b->length > 0 && b->store[0] < a->store[0]) {
			b->length--;
			b->store += 2;
		}
	}
	done: return out;
}
