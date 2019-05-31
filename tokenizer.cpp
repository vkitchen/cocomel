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

static inline int prefix(const char *pre, const char *str) {
	while (*pre) {
		if (*pre++ != *str++) {
			return 0;
		}
	}
	return 1;
}

static inline void tokenizer_advance(struct tokenizer *tok) {
	for (;;) {
		// EOF
		if (tok->index == tok->str->bytes)
			break;
		// Word
		else if (isalnum(tok->str->str[tok->index]))
			break;
		// Doc ID
		else if (prefix("<DOCNO>", &tok->str->str[tok->index]))
			break;
		// Ignored tags
		else if (tok->str->str[tok->index] == '<') {
			tok->index++;
			while (tok->index < tok->str->bytes && tok->str->str[tok->index] != '>')
				tok->index++;
			tok->index++;
		}
		// Other punctuation
		else if (!isalnum(tok->str->str[tok->index]))
			tok->index++;

		// Whitespace
		while(tok->index < tok->str->bytes && isspace(tok->str->str[tok->index]))
			tok->index++;
	}
}

enum token_type tokenizer_next(struct tokenizer *tok, char *word) {
	tokenizer_advance(tok);

	if (prefix("<DOCNO>", &tok->str->str[tok->index])) {
		tok->index += sizeof("<DOCNO>"); // TODO might be skipping 1 too many?

		while(tok->index < tok->str->bytes && isspace(tok->str->str[tok->index])) {
			tok->index++;
		}

		int i = 0;
		while (i < 256 && i + tok->index < tok->str->bytes && tok->str->str[tok->index + i] != '<' && !isspace(tok->str->str[tok->index + i])) {
			word[i+4] = tok->str->str[tok->index + i];
			i++;
		}
		((uint32_t *)word)[0] = i;
		word[i+4] = '\0';

		tok->index += i;

		return DOCNO;
	}

	if (tok->index < tok->str->bytes && isdigit(tok->str->str[tok->index])) {
		int i = 0;
		while (i < 256 && i + tok->index < tok->str->bytes && isdigit(tok->str->str[tok->index + i])) {
			word[i+4] = tok->str->str[tok->index + i];
			i++;
		}
		((uint32_t *)word)[0] = i;
		word[i+4] = '\0';

		tok->index += i;

		return WORD;
	}

	if (tok->index < tok->str->bytes && isalpha(tok->str->str[tok->index])) {
		int i = 0;
		while (i < 256 && i + tok->index < tok->str->bytes && isalpha(tok->str->str[tok->index + i])) {
			char c = tok->str->str[tok->index + i];
			if ('Z' < c) {
				c -= 'a' - 'A';
			}
			word[i+4] = c;
			i++;
		}
		((uint32_t *)word)[0] = i;
		word[i+4] = '\0';

		tok->index += i;

		return WORD;
	}

	return END;
}
