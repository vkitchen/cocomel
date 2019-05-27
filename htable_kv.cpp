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
    h->lengths = (uint32_t *)memory_alloc(sizeof(uint32_t) * h->capacity);
    for (size_t i = 0; i < h->capacity; i++) {
        h->store[i] = NULL;
        h->lengths[i] = 0;
    }
    return h;
}

void **htable_kv_insert(struct htable_kv *h, char *key, void *val)
{
	unsigned int hash = htable_word_to_int(&key[4]) & (1 << 16) - 1;
	if (h->store[hash] == NULL) {
		h->store[hash] = bst_kv_new(key, val);
		h->lengths[hash]++;
		return &h->store[hash]->val;
	}
	return bst_kv_insert(h->store[hash], key, val, &h->lengths[hash]);
}

void *htable_kv_find(struct htable_kv *h, char *key)
{
	unsigned int hash = htable_word_to_int(key) & (1 << 16) - 1;
	if (h->store[hash] == NULL) {
		return NULL;
	}

	char *ptr_store = (char *)h->store + (size_t)h->store[hash];
	uint32_t length = *(uint32_t *)ptr_store;

	size_t *vec = (size_t *)(ptr_store + sizeof(uint32_t));

	for (size_t i = 0; i < length; i++)
		if (strcmp(key, (char *)h->store + vec[i*2]) == 0)
			return (char *)h->store + vec[i*2+1];

	return NULL;
}

static inline unsigned int htable_word_to_int(char *key) {
    unsigned int result = 0;

    while (*key != '\0') {
        result = (*key++ + 31 * result);
    }
    return result;
}

size_t htable_kv_write(struct htable_kv *h, char *buffer) {
	size_t delta = sizeof(struct bst_kv *) * h->capacity;
	for (size_t i = 0; i < h->capacity; i++) {
		if (h->store[i] != NULL) {
			size_t start = delta;

			((uint32_t *)&buffer[delta])[0] = h->lengths[i];
			delta += sizeof(uint32_t);
			size_t ptr_offset = h->lengths[i] * 2 * sizeof(char *);
			char *ptr_store = &buffer[delta];
			char *data_store = &buffer[delta + ptr_offset];
			bst_kv_write(h->store[i], &ptr_store, &data_store);
			delta += data_store - &buffer[delta];

			h->store[i] = (struct bst_kv *)start;
		}
	}

	memcpy(&buffer[0], h->store, sizeof(struct bst_kv *) * h->capacity);

	return delta;
}

struct htable_kv *htable_kv_read(char *buffer) {
	struct htable_kv *h = (struct htable_kv *)memory_alloc(sizeof(struct htable_kv));
	h->capacity = 1 << 16;
	h->store = (struct bst_kv **)buffer;
	h->lengths = NULL;
	for (size_t i = 0; i < h->capacity; i++) {

		if (h->store[i] == NULL)
			continue;

		uint32_t length = *(uint32_t *)(buffer + (size_t)h->store[i]);
		char *ptr_store = buffer + (size_t)h->store[i] + sizeof(uint32_t);

		for (size_t j = 0; j < length * 2; j++) {
			((size_t *)ptr_store)[0] = ptr_store + ((size_t *)ptr_store)[0] - buffer;
			ptr_store += sizeof(size_t);
		}

	}
	return h;
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
