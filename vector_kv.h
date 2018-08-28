#ifndef VECTOR_KV_H_
#define VECTOR_KV_H_

struct vector_kv {
	size_t capacity;
	size_t length;
	void **items;
};

struct vector_kv *vector_kv_new();
void vector_kv_append(struct vector_kv *v, char *key, void *val);
void *vector_kv_find(struct vector_kv *v, char *key);
void vector_kv_sort(struct vector_kv *v);

#endif
