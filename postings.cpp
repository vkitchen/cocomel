#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <utility>
#include "dynamic_array.h"
#include "string2.h"
#include "bst_kv.h"
#include "htable_kv.h"
#include "vector_kv.h"
#include "posting.h"
#include "postings.h"


struct postings *postings_new() {
	struct postings *p = (struct postings *)memory_alloc(sizeof(struct postings));
	p->docI = -1;
	p->docNos = new dynamic_array<std::pair<char *, size_t>>();
	p->dictionary = htable_kv_new();
	return p;
}

void postings_new_doc(struct postings *p, char *doc) {
	p->docI++;
	p->docNos->append(std::make_pair(doc, 0));
}

void postings_append(struct postings *p, char *term) {
	p->docNos->back()->second++;
	struct posting **posting = (struct posting **)htable_kv_insert(p->dictionary, term, NULL);
	if (*posting == NULL) {
		*posting = posting_new();
	}
	posting_append(*posting, p->docI);
}


void postings_write(struct postings *p, struct string *buffer, char const *filename) {
	FILE *fh = fopen(filename, "w");
	if (fh == NULL) {
		fprintf(stderr, "ERROR: Failed to open postings.dat for writing\n");
		exit(1);
	}

	struct bst_kv *dict_list = htable_kv_merge(p->dictionary);
	struct vector_kv *dict_vect = vector_kv_new();

	// Write to output buffer
	size_t offset = 8;

	((size_t *)&buffer->str[offset])[0] = p->docNos->length;
	size_t docNos_offset = offset + sizeof(p->docNos->length);
	offset += sizeof(p->docNos->length) + p->docNos->length * (sizeof(char *) + sizeof(size_t));
	for (size_t i = 0; i < p->docNos->length; i++) {
		((size_t *)&buffer->str[docNos_offset])[0] = offset;
		((size_t *)&buffer->str[docNos_offset])[1] = p->docNos->store[i].second;
		docNos_offset += sizeof(size_t) * 2;

		offset += string_copy_c(&buffer->str[offset], p->docNos->store[i].first);
	}

	struct bst_kv_node *dict_node = dict_list->root;
	do {
		size_t delta = posting_write((struct posting *)dict_node->val, &buffer->str[offset]);
		vector_kv_append(dict_vect, dict_node->key, (void *)offset);

		offset += delta;
		dict_node = dict_node->link[1];
	} while (dict_node != dict_list->root);

	((size_t *)buffer->str)[0] = offset;
	offset += vector_kv_write(dict_vect, &buffer->str[offset]);

	fwrite(buffer->str, sizeof(char), offset, fh);
	fclose(fh);
}
