#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "string2.h"
#include "bst_kv.h"
#include "htable_kv.h"
#include "vector_kv.h"
#include "posting.h"
#include "postings.h"

static size_t string_copy(char *dest, char *src) {
	size_t offset = 0;
	while (src[offset] != '\0') {
		dest[offset] = src[offset];
		offset++;
	}
	dest[offset] = '\0';
	offset++;
	return offset;
}


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
	size_t offset = 16;
	for (size_t i = 0; i < p->docNos->length; i++) {
		size_t delta = string_copy(&buffer->str[offset], p->docNos->store[i * 2]);
		p->docNos->store[i * 2] = (void *)offset;
		offset += delta;
	}
//	printf("doc store %zd\n", offset);
	memcpy(&buffer->str[offset], p->docNos->store, sizeof(size_t) * p->docNos->length * 2);
	p->docNos->store = (void **)offset;
	offset += sizeof(size_t) * p->docNos->length * 2;
	memcpy(&buffer->str[offset], p->docNos, sizeof(struct vector_kv));
	((size_t *)buffer->str)[0] = offset;
	offset += sizeof(struct vector_kv);

	struct bst_kv_node *dict_node = dict_list->root;
	do {
		size_t key_pos = offset;
		offset += string_copy(&buffer->str[offset], dict_node->key);

		struct posting *posting = dict_node->val;
		posting_flush(posting);

		memcpy(&buffer->str[offset], posting->id_store, posting->id_length);
		posting->id_store = (void *)offset;
		offset += posting->id_length;

		memcpy(&buffer->str[offset], posting->count_store, sizeof(uint16_t) * posting->count_length);
		posting->count_store = (void *)offset;
		offset += sizeof(uint16_t) * posting->count_length;

		// TODO perhaps this is storing too much?
		size_t val_pos = offset;
		memcpy(&buffer->str[offset], dict_node->val, sizeof(struct posting));
		offset += sizeof(struct posting);

		vector_kv_append(dict_vect, (void *)key_pos, (void *)val_pos);
		dict_node = dict_node->link[1];
	} while (dict_node != dict_list->root);

	memcpy(&buffer->str[offset], dict_vect->store, sizeof(size_t) * dict_vect->length * 2);
	dict_vect->store = (void **)offset;
	offset += sizeof(size_t) * dict_vect->length * 2;
	memcpy(&buffer->str[offset], dict_vect, sizeof(struct vector_kv));
	((size_t *)buffer->str)[1] = offset;
	offset += sizeof(struct vector_kv);

//	exit(0);

	fwrite(buffer->str, sizeof(char), offset, fh);
	fclose(fh);
}
