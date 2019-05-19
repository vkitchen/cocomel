#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "memory.h"
#include "bst_kv.h"
#include "htable_kv.h"
#include "vector_kv.h"

static inline unsigned int htable_word_to_int(char *key);

struct htable_kv *htable_kv_new()
{
    struct htable_kv *h = (struct htable_kv *)memory_alloc(sizeof(struct htable_kv));
    h->capacity = 1 << 16;
    h->store = (struct bst_kv **)memory_alloc(sizeof(struct bst_kv *) * h->capacity);
    for (size_t i = 0; i < h->capacity; i++) {
        h->store[i] = NULL;
    }
    return h;
}

void **htable_kv_insert(struct htable_kv *h, char *key, void *val)
{
	unsigned int hash = htable_word_to_int(&key[4]) & (1 << 16) - 1;
	if (h->store[hash] == NULL) {
		h->store[hash] = bst_kv_new(key, val);
		return &h->store[hash]->val;
	}
	return bst_kv_insert(h->store[hash], key, val);
}

void *htable_kv_find(struct htable_kv *h, char *key)
{
	unsigned int hash = htable_word_to_int(key) & (1 << 16) - 1;
	if (h->store[hash] == NULL) {
		return NULL;
	}
	return bst_kv_find(h->store[hash], key);
}

static inline unsigned int htable_word_to_int(char *key) {
    unsigned int result = 0;

    while (*key != '\0') {
        result = (*key++ + 31 * result);
    }
    return result;
}

struct vector_kv *htable_kv_merge(struct htable_kv *h) {
	struct vector_kv *postings = vector_kv_new();

	for (size_t i = 0; i < h->capacity; i++) {
		if (h->store[i] != NULL) {
			bst_kv_to_vector(h->store[i], postings);
		}
	}

	vector_kv_sort(postings);

	return postings;
}
