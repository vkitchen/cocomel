#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "stdlib2/string2.h"
#include "stdlib2/file.h"
#include "stdlib2/memory.h"
#include "flexarray.h"
#include "rb_tree/rb_tree.h"
#include "htable_kv.h"
#include "vector_kv.h"

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

int prefix(const char *pre, const char *str)
{
	return strncmp(pre, str, strlen(pre)) == 0;
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
		tok->index += sizeof("<DOCNO>");

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
			if (90 < c) {
				c -= 'a' - 'A';
			}
			if (c < 48 || (57 < c && c < 65) || 90 < c) {
				i++;
				continue;
			}
			word[j] = tok->str->str[tok->index + i];
			i++;
			j++;
		}
		word[j] = '\0';
		token.type = WORD;
		token.value = memory_alloc(j+1);
		memcpy(token.value, word, j+1);

		tok->index += i;
		tokenizer_advance(tok);

		return token;
	}

	token.type = END;
	return token;
}

struct posting {
	char *word;
	flexarray list;
};

int rbt_cmp(struct rb_tree *self, struct rb_node *a_node, struct rb_node *b_node) {
	struct posting *a = (struct posting *)a_node->value;
	struct posting *b = (struct posting *)b_node->value;
	return strcmp(a->word, b->word);
}

int main(void) {
	struct string *file = file_slurp_c("wsj.xml");
	struct tokenizer *tok = tokenizer_new(file);
	flexarray docNos = flexarray_new(1024);
//	struct rb_tree *postings = rb_tree_create(rbt_cmp);
	struct htable_kv *postings = htable_kv_new(10000);
	struct token token;
	size_t docI = -1;
	do {
		token = tokenizer_next(tok);
		if (token.type == DOCNO) {
			docI++;
			flexarray_append(docNos, token.value);
		} else if (token.type != END) {
			flexarray list = htable_kv_find(postings, token.value);
//			struct posting *post = malloc(sizeof(struct posting));
//			post->word = token.value;
//			struct posting *post_exist = rb_tree_find(postings, post);
			if (list != NULL) {
				int length = flexarray_length(list);
				if (length == 0 || (size_t)flexarray_get(list, length-1) != docI) {
					flexarray_append(list, (void *)docI);
				}
			} else {
				list = flexarray_new(1024);
				flexarray_append(list, (void *)docI);
				htable_kv_insert(postings, token.value, list);
//				rb_tree_insert(postings, post);
			}
		}
	} while (token.type != END);

//	struct vector_kv *out_list = htable_kv_merge(postings);
//	struct vector_kv *out_list = vector_kv_new();
//	for (size_t i = 0; i < postings->capacity; i++) {
//		if (postings->store[i] == NULL) {
//			continue;
//		}
//		for (size_t j = 0; j < postings->store[i]->length; j++) {
//			vector_kv_append(out_list, postings->store[i]->items[j * 2], postings->store[i]->items[j * 2 + 1]);
//		}
//	}
//
//	vector_kv_sort(out_list);
//
//	for (size_t i = 0; i < out_list->length; i++) {
//		printf("%s\n", out_list->items[i*2]);
//	}

	exit(0);

//	std::ofstream fh;
//	fh.open("postings.dat", std::ios::binary);
//	size_t docCount = docNos.size();
//	fh.write((char *)&docCount, 8);
//	for (auto &docNo : docNos) {
//		size_t docNoSize = docNo.size();
//		fh.write((char *)&docNoSize, 8);
//		fh.write(&docNo[0], docNoSize);
//	}
//	size_t postingsLength = postings.size();
//	fh.write((char *)&postingsLength, 8);
//	for (auto &post : postings) {
//		size_t stringLength = post.first.size();
//		fh.write((char *)&stringLength, 8);
//		fh.write(&post.first[0], stringLength);
//		size_t listLength = post.second.size();
//		fh.write((char *)&listLength, 8);
//		for (auto &list : post.second) {
//			fh.write((char *)&list, 8);
//		}
//	}
//	fh.close();

	return 0;
}
