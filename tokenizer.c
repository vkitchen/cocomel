#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "memory.h"
#include "string2.h"
#include "tokenizer.h"

struct tokenizer *tokenizer_new(struct string *str) {
	struct tokenizer *tok = (struct tokenizer *)memory_alloc(sizeof(struct tokenizer));
	tok->str = str;
	tok->index = 0;
	return tok;
}

static int prefix(const char *pre, const char *str) {
	while (*pre) {
		if (*pre++ != *str++) {
			return 0;
		}
	}
	return 1;
}

static void tokenizer_advance(struct tokenizer *tok) {
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
