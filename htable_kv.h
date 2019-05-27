#ifndef HTABLE_KV_H_
#define HTABLE_KV_H_

//#include "vector_kv.h"

struct htable_kv {
	size_t capacity;
	struct bst_kv **store;
	uint32_t *lengths;
};

struct htable_kv *htable_kv_new();
void **htable_kv_insert(struct htable_kv *h, char *key, void *val);
void *htable_kv_find(struct htable_kv *h, char *key);
size_t htable_kv_write(struct htable_kv *h, char *buffer);
struct htable_kv *htable_kv_read(char *buffer);

#endif
