#ifndef TOKENIZER_H
#define TOKENIZER_H

#include "memory.h"
#include "str.h"

enum token_type {DOCNO, WORD, END};

struct tokenizer
	{
	size_t index;
	size_t length;
	char *document;
	};

void tokenizer_init(struct tokenizer *t, char *doc, size_t len);
enum token_type tokenizer_next(struct tokenizer *t, struct str buffer);

#endif

