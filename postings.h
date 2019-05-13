#ifndef POSTINGS_H_
#define POSTINGS_H_

#include<utility>
#include "dynamic_array.h"

struct postings {
	size_t docI;
	dynamic_array<std::pair<char *, size_t>> *docNos;
	struct htable_kv *dictionary;
};

struct postings *postings_new();
void postings_new_doc(struct postings *p, char *doc);
void postings_append(struct postings *p, char *term);
void postings_write(struct postings *p, struct string *buffer, char const *filename);

#endif
