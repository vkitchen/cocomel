#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "memory.h"
#include "linked_vector_kv.h"

struct linked_vector_kv *linked_vector_kv_new() {
	struct linked_vector_kv *v = memory_alloc(sizeof(struct linked_vector_kv));
	v->capacity = 256;
	v->length = 0;
	v->store = memory_alloc(v->capacity * 2 * sizeof(void *));
	v->link[0] = v;
	v->link[1] = v;
	return v;
}

void linked_vector_kv_append(struct linked_vector_kv *v, char *key, void *val) {
	struct linked_vector_kv *last = v->link[0];
	if (last->length == last->capacity) {
		last = linked_vector_kv_new();
		last->link[0] = v->link[0];
		last->link[1] = v;
		v->link[0]->link[1] = last;
		v->link[0] = last;
	}
	last->store[last->length * 2] = key;
	last->store[last->length * 2 + 1] = val;
	last->length++;
}

// void *linked_vector_kv_find(struct linked_vector_kv *v, char *key) {
// 	for (size_t i = 0; i < v->length; i++) {
// 		if (strcmp(key, v->store[i * 2]) == 0) {
// 			return v->store[i * 2 + 1];
// 		}
// 	}
// 	return NULL;
// }

/* Returns reference to cell that key is stored in */
void *linked_vector_kv_back(struct linked_vector_kv *v) {
	if (v->length == 0) {
		return NULL;
	}
	v = v->link[0];
	return &v->store[(v->length-1) * 2];
}
