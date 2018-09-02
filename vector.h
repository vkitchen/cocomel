#ifndef VECTOR_H_
#define VECTOR_H_

struct vector {
	size_t capacity;
	size_t length;
	void **store;
};

struct vector *vector_new();
void vector_append(struct vector *v, void *val);

#endif
