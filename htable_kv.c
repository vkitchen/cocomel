#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "htable_kv.h"
#include "rbt_kv.h"

static unsigned int htable_word_to_int(char *key);

struct htable_kv *htable_kv_new(size_t capacity)
{
    struct htable_kv *h = malloc(sizeof(struct htable_kv));
    h->capacity = capacity;
    h->store = malloc(sizeof(struct vector_kv *) * capacity);
    for (size_t i = 0; i < capacity; i++) {
        h->store[i] = NULL;
    }
    return h;
}

void htable_kv_insert(struct htable_kv *h, char *key, void *val)
{
    unsigned int hash = htable_word_to_int(key) % h->capacity;
	if (h->store[hash] == NULL) {
		h->store[hash] = rbt_kv_new();
	}
	rbt_kv_insert(h->store[hash], key, val);
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

// static struct vector_kv *merge(struct vector_kv *a, struct vector_kv *b) {
// 	vector_kv_sort(b);
// 
// 	struct vector_kv *out = vector_kv_new();
// 	size_t i = 0;
// 	size_t j = 0;
// 	while (i < a->length && j < b->length) {
// 		int res;
// 		if (!(i < a->length)) {
// 			res = 1;
// 		} else if (!(j < b->length)) {
// 			res = -1;
// 		} else {
// 			res = strcmp(a->items[i * 2], b->items[j * 2]);
// 		}
// 		if (res <= 0) {
// 			vector_kv_append(out, a->items[i * 2], a->items[i * 2 + 1]);
// 			i++;
// 		} else {
// 			vector_kv_append(out, b->items[j * 2], b->items[j * 2 + 1]);
// 			j++;
// 		}
// 	}
// 	return out;
// }
// 
// struct vector_kv *htable_kv_merge(struct htable_kv *h) {
// 	size_t i;
// 	for (i = 0; i < h->capacity; i++) {
// 		if (h->store[i] != NULL) {
// 			vector_kv_sort(h->store[i]);
// 			break;
// 		}
// 	}
// 	if (h->store[i] == NULL) {
// 		return NULL;
// 	}
// 	int merged = 1;
// 	while (merged) {
// 		merged = 0;
// 		for (size_t j = i+1; j < h->capacity; j++) {
// 			if (h->store[j] != NULL) {
// 				h->store[i] = merge(h->store[i], h->store[j]);
// 				h->store[j] = NULL;
// 				merged = 1;
// 				break;
// 			}
// 		}
// 	}
// 	return h->store[i];
// }
