#include <stdio.h>
#include <stdint.h>
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

enum token_type tokenizer_next(struct tokenizer *tok, char *word) {
	tokenizer_advance(tok);

	if (prefix("<DOCNO>", &tok->str->str[tok->index])) {
		tok->index += sizeof("<DOCNO>"); // TODO might be skipping 1 too many?

		tokenizer_advance(tok);

		int i = 0;
		while (i < 256 && i + tok->index < tok->str->bytes && !isspace(tok->str->str[tok->index + i])) {
			word[i+4] = tok->str->str[tok->index + i];
			i++;
		}
		((uint32_t *)word)[0] = i;
		word[i+4] = '\0';

		tok->index += i;
		tokenizer_advance(tok);

		return DOCNO;
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
			word[j+4] = c;
			i++;
			j++;
		}

		tok->index += i;
		tokenizer_advance(tok);

		if (j == 0) {
			return EMPTY;
		}
		((uint32_t *)word)[0] = j;
		word[j+4] = '\0';

		return WORD;
	}

	return END;
}
