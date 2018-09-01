#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "stdlib2/string2.h"
#include "stdlib2/file.h"
#include "stdlib2/memory.h"
#include "flexarray.h"
#include "htable_kv.h"
#include "vector_kv.h"
#include "rbt_kv.h"
#include "linked_vector_kv.h"
#include "postings.h"

enum token_type {DOCNO, WORD, END};
struct token {
	char *value;
	enum token_type type;
};

struct tokenizer {
	struct string *str;
	size_t index;
};

struct tokenizer *tokenizer_new(struct string *str) {
	struct tokenizer *tok = (struct tokenizer *)memory_alloc(sizeof(struct tokenizer));
	tok->str = str;
	tok->index = 0;
	return tok;
}

int prefix(const char *pre, const char *str) {
	while (*pre) {
		if (*pre++ != *str++) {
			return 0;
		}
	}
	return 1;
}

void tokenizer_advance(struct tokenizer *tok) {
	// Whitespace
	while(tok->index < tok->str->bytes && isspace(tok->str->str[tok->index])) {
		tok->index++;
	}

	// Ignored tags
	while (tok->index < tok->str->bytes && tok->str->str[tok->index] == '<' && !prefix("<DOCNO>", &tok->str->str[tok->index])) {
		char *found = strstr(&tok->str->str[tok->index], ">");
		if (found == NULL) {
			fprintf(stderr, "ERROR: Tokenizer encountered unmatched <");
		}
		tok->index += found - &tok->str->str[tok->index] + 1; // jump over the closing arrow bracket

		while(tok->index < tok->str->bytes && isspace(tok->str->str[tok->index])) {
			tok->index++;
		}
	}
}

struct token tokenizer_next(struct tokenizer *tok) {
	struct token token;
	char word[256];

	tokenizer_advance(tok);

	if (prefix("<DOCNO>", &tok->str->str[tok->index])) {
		tok->index += sizeof("<DOCNO>"); // TODO might be skipping 1 too many?

		tokenizer_advance(tok);

		int i = 0;
		while (i < 256 && i + tok->index < tok->str->bytes && !isspace(tok->str->str[tok->index + i])) {
			word[i] = tok->str->str[tok->index + i];
			i++;
		}
		word[i] = '\0';
		token.type = DOCNO;
		token.value = memory_alloc(i+1);
		memcpy(token.value, word, i+1);

		tok->index += i;
		tokenizer_advance(tok);

		return token;
	}

	if (tok->index < tok->str->bytes) {
		int i = 0;
		int j = 0;
		while (j < 256 && i + tok->index < tok->str->bytes && !isspace(tok->str->str[tok->index + i]) && tok->str->str[tok->index + i] != '<') {
			char c = tok->str->str[tok->index + i];
			if ('Z' < c) {
				c -= 'a' - 'A';
			}
			if (!('A' <= c && c <= 'Z')) {
				i++;
				continue;
			}
			word[j] = c;
			i++;
			j++;
		}

		tok->index += i;
		tokenizer_advance(tok);

		token.type = WORD;
		if (j == 0) {
			token.value = NULL;
			return token;
		}
		word[j] = '\0';
		token.value = memory_alloc(j+1);
		memcpy(token.value, word, j+1);


		return token;
	}

	token.type = END;
	return token;
}

// size_t string_copy(char *dest, char *src) {
// 	size_t out = strlen(src);
// 	strcpy(dest, src);
// 	return out;
// }

size_t string_copy(char *dest, char *src) {
	size_t offset = 0;
	while (src[offset] != '\0') {
		dest[offset] = src[offset];
		offset++;
	}
	src[offset] = '\0';
	offset++;
	return offset;
}

int main(void) {
	struct string *file = file_slurp_c("wsj.xml");
	struct tokenizer *tok = tokenizer_new(file);
	struct vector_kv *docNos = vector_kv_new();
	struct htable_kv *dictionary = htable_kv_new();
	struct token token;
	u_int16_t docI = -1;
	do {
		token = tokenizer_next(tok);
		if (token.type == DOCNO) {
			docI++;
			vector_kv_append(docNos, token.value, 0);
//			printf("DOCNO: %s\n", token.value);
		} else if (token.type != END) {
			if (token.value == NULL) {
				continue; /* From stripped bare symbols */
			}
			size_t *docLength = (size_t *)vector_kv_back(docNos);
			docLength[1]++;
			struct postings *postings = htable_kv_find(dictionary, token.value);
			if (postings == NULL) {
				postings = postings_new();
				htable_kv_insert(dictionary, token.value, postings);
			}
			postings_append(postings, docI);
		}
	} while (token.type != END);

	struct rbt_kv *dict_list = htable_kv_merge(dictionary);
	struct vector_kv *dict_vect = vector_kv_new();

	// Write to output buffer
	size_t offset = 16;
	for (size_t i = 0; i < docNos->length; i++) {
		size_t delta = string_copy(&file->str[offset], docNos->store[i * 2]);
		docNos->store[i * 2] = (void *)offset;
		offset += delta;
	}
	memcpy(&file->str[offset], docNos->store, sizeof(size_t) * docNos->length * 2);
	((size_t *)file->str)[0] = offset;
	offset += sizeof(size_t) * docNos->length * 2;

	struct rbt_kv_node *dict_node = dict_list->root;
	do {
		size_t key_pos = offset;
		offset += string_copy(&file->str[offset], dict_node->key);

		struct postings *postings = dict_node->val;
		postings_flush(postings);

		memcpy(&file->str[offset], postings->id_store, postings->id_length);
		postings->id_store = (void *)offset;
		offset += postings->id_length;

		memcpy(&file->str[offset], postings->count_store, sizeof(uint16_t) * postings->count_length);
		postings->count_store = (void *)offset;
		offset += sizeof(uint16_t) * postings->count_length;

		// TODO perhaps this is storing too much?
		size_t val_pos = offset;
		memcpy(&file->str[offset], dict_node->val, sizeof(struct postings));
		offset += sizeof(struct postings);

		vector_kv_append(dict_vect, (void *)key_pos, (void *)val_pos);
		dict_node = dict_node->link[1];
	} while (dict_node != dict_list->root);

	memcpy(&file->str[offset], dict_vect->store, sizeof(size_t) * dict_vect->length * 2);
	((size_t *)file->str)[1] = offset;
	offset += sizeof(size_t) * dict_vect->length * 2;

	FILE *fh = fopen("postings.dat", "w");
	if (fh == NULL) {
		fprintf(stderr, "ERROR: Failed to open postings.dat for writing\n");
		exit(1);
	}
	fwrite(file->str, sizeof(char), offset, fh);
	fclose(fh);

	return 0;
}
