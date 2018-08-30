#ifndef LINKED_VECTOR_KV_H_
#define LINKED_VECTOR_KV_H_

struct linked_vector_kv {
	size_t capacity;
	size_t length;
	void **store;
	struct linked_vector_kv *link[2];
};

struct linked_vector_kv *linked_vector_kv_new();
void linked_vector_kv_append(struct linked_vector_kv *v, char *key, void *val);
void *linked_vector_kv_find(struct linked_vector_kv *v, char *key);
void *linked_vector_kv_back(struct linked_vector_kv *v);

#endif
