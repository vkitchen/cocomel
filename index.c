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
			word[j] = c;
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

int main(void) {
	struct string *file = file_slurp_c("wsj.xml");
	struct tokenizer *tok = tokenizer_new(file);
	struct linked_vector_kv *docNos = linked_vector_kv_new();
	struct htable_kv *dictionary = htable_kv_new();
	struct token token;
	u_int16_t docI = -1;
	do {
		token = tokenizer_next(tok);
		if (token.type == DOCNO) {
			docI++;
			linked_vector_kv_append(docNos, token.value, 0);
		} else if (token.type != END) {
			size_t *docLength = (size_t *)(linked_vector_kv_back(docNos)+1);
			(*docLength)++;
			struct postings *postings = htable_kv_find(dictionary, token.value);
			if (postings == NULL) {
				postings = postings_new();
				htable_kv_insert(dictionary, token.value, postings);
			}
			postings_append(postings, docI);
		}
	} while (token.type != END);

	htable_kv_merge(dictionary);

	return 0;
}
