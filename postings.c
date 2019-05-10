#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "string2.h"
#include "bst_kv.h"
#include "htable_kv.h"
#include "vector_kv.h"
#include "posting.h"
#include "postings.h"


struct postings *postings_new() {
	struct postings *p = malloc(sizeof(struct postings));
	p->docI = -1;
	p->docNos = vector_kv_new();
	p->dictionary = htable_kv_new();
	return p;
}

void postings_new_doc(struct postings *p, char *doc) {
	p->docI++;
	vector_kv_append(p->docNos, doc, 0);
}

void postings_append(struct postings *p, char *term) {
	size_t *docLength = (size_t *)vector_kv_back(p->docNos);
	docLength[1]++;
	struct posting **posting = (struct posting **)htable_kv_insert(p->dictionary, term, NULL);
	if (*posting == NULL) {
		*posting = posting_new();
	}
	posting_append(*posting, p->docI);
}


void postings_write(struct postings *p, struct string *buffer, char *filename) {
	FILE *fh = fopen(filename, "w");
	if (fh == NULL) {
		fprintf(stderr, "ERROR: Failed to open postings.dat for writing\n");
		exit(1);
	}

	struct bst_kv *dict_list = htable_kv_merge(p->dictionary);
	struct vector_kv *dict_vect = vector_kv_new();

	// Write to output buffer
	size_t offset = 8;

	offset += vector_kv_write(p->docNos, &buffer->str[offset]);

	struct bst_kv_node *dict_node = dict_list->root;
	do {
		size_t delta = posting_write(dict_node->val, &buffer->str[offset]);
		vector_kv_append(dict_vect, dict_node->key, (void *)offset);

		offset += delta;
		dict_node = dict_node->link[1];
	} while (dict_node != dict_list->root);

	((size_t *)buffer->str)[0] = offset;
	offset += vector_kv_write(dict_vect, &buffer->str[offset]);

	fwrite(buffer->str, sizeof(char), offset, fh);
	fclose(fh);
}
