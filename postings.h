#ifndef POSTINGS_H_
#define POSTINGS_H_

struct postings {
	size_t capacity;
	size_t length;
	size_t *store;
};

struct postings *postings_new();
void postings_append(struct postings *p, size_t id);

#endif
