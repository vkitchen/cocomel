#ifndef POSTINGS_H_
#define POSTINGS_H_

struct postings {
	u_int16_t docI;
	struct vector_kv *docNos;
	struct htable_kv *dictionary;
};

struct postings *postings_new();
void postings_new_doc(struct postings *p, char *doc);
void postings_append(struct postings *p, char *term);
void postings_write(struct postings *p, struct string *buffer, char *filename);

#endif
