#ifndef HTABLE_KV_H_
#define HTABLE_KV_H_

//#include "vector_kv.h"

struct htable_kv {
	size_t capacity;
	struct rbt_kv **store;
};

struct htable_kv *htable_kv_new();
void **htable_kv_insert(struct htable_kv *h, char *key, void *val);
void *htable_kv_find(struct htable_kv *h, char *key);
void htable_kv_merge(struct htable_kv *h);

#endif
