#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "memory.h"
#include "bst_kv.h"
#include "htable_kv.h"

static unsigned int htable_word_to_int(char *key);

struct htable_kv *htable_kv_new()
{
    struct htable_kv *h = (struct htable_kv *)memory_alloc(sizeof(struct htable_kv));
    h->capacity = 32768;
    h->store = (struct bst_kv **)memory_alloc(sizeof(struct bst_kv *) * h->capacity);
    for (size_t i = 0; i < h->capacity; i++) {
        h->store[i] = NULL;
    }
    return h;
}

void **htable_kv_insert(struct htable_kv *h, char *key, void *val)
{
    unsigned int hash = htable_word_to_int(&key[4]) % h->capacity;
	if (h->store[hash] == NULL) {
		h->store[hash] = bst_kv_new();
	}
	return bst_kv_insert(h->store[hash], key, val);
}

void *htable_kv_find(struct htable_kv *h, char *key)
{
    unsigned int hash = htable_word_to_int(key) % h->capacity;
	if (h->store[hash] == NULL) {
		return NULL;
	}
	return bst_kv_find(h->store[hash], key);
}

static unsigned int htable_word_to_int(char *key) {
    unsigned int result = 0;

    while (*key != '\0') {
        result = (*key++ + 31 * result);
    }
    return result;
}

struct bst_kv *htable_kv_merge(struct htable_kv *h) {
	size_t total_size = 0;
	for (size_t i = 0; i < h->capacity; i++) {
		if (h->store[i] != NULL) {
			total_size += h->store[i]->size;
			bst_kv_linked_list(h->store[i]);
		}
	}
//	printf("RBT total %zd\n", total_size);
	for (size_t gap = 1; gap < h->capacity; gap *= 2) {
		for (size_t i = 0; i < h->capacity; i += gap * 2) {
			if (h->store[i] == NULL) {
				h->store[i] = h->store[i+gap];
				continue;
			}
			bst_kv_merge_left(h->store[i], h->store[i+gap]);
		}
	}
//	bst_kv_print_list(h->store[0]);
	return h->store[0];
}
