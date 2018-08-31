#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "htable_kv.h"
#include "rbt_kv.h"

static unsigned int htable_word_to_int(char *key);

struct htable_kv *htable_kv_new()
{
    struct htable_kv *h = malloc(sizeof(struct htable_kv));
    h->capacity = 32768;
    h->store = malloc(sizeof(struct vector_kv *) * h->capacity);
    for (size_t i = 0; i < h->capacity; i++) {
        h->store[i] = NULL;
    }
    return h;
}

void **htable_kv_insert(struct htable_kv *h, char *key, void *val)
{
    unsigned int hash = htable_word_to_int(key) % h->capacity;
	if (h->store[hash] == NULL) {
		h->store[hash] = rbt_kv_new();
	}
	return rbt_kv_insert(h->store[hash], key, val);
}

void *htable_kv_find(struct htable_kv *h, char *key)
{
    unsigned int hash = htable_word_to_int(key) % h->capacity;
	if (h->store[hash] == NULL) {
		return NULL;
	}
	return rbt_kv_find(h->store[hash], key);
}

static unsigned int htable_word_to_int(char *key) {
    unsigned int result = 0;

    while (*key != '\0') {
        result = (*key++ + 31 * result);
    }
    return result;
}

void htable_kv_merge(struct htable_kv *h) {
	size_t total_size = 0;
	for (size_t i = 0; i < h->capacity; i++) {
		if (h->store[i] != NULL) {
			total_size += h->store[i]->size;
			rbt_kv_linked_list(h->store[i]);
		}
	}
	printf("RBT total %zd\n", total_size);
	for (size_t gap = 1; gap < h->capacity; gap *= 2) {
		for (size_t i = 0; i < h->capacity; i += gap * 2) {
			if (h->store[i] == NULL) {
				h->store[i] = h->store[i+gap];
				continue;
			}
			rbt_kv_merge_left(h->store[i], h->store[i+gap]);
		}
	}
//	rbt_kv_print_list(h->store[0]);
}
