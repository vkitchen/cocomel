#ifndef POSTING_H_
#define POSTING_H_

struct posting {
	size_t capacity;
	size_t length;
	size_t *store;
};

struct posting *posting_new();
void posting_append(struct posting *p, size_t id);

#endif
