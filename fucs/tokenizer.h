#ifndef TOKENIZER_H
#define TOKENIZER_H

#include "char.h"
#include "str.h"
#include "fucs.h"

struct tokenizer
	{
	size_t index;
	size_t length;
	char *document;
	};

static inline void tokenizer_init(struct tokenizer *t, char *doc, size_t len)
	{
	t->index = 0;
	t->length = len;
	t->document = doc;
	}

static inline enum token_type tokenizer_next(struct tokenizer *t, struct str buffer)
	{
	for (;;)
		{
		// Whitespace
		while(t->index < t->length && char_isspace(t->document[t->index]))
			t->index++;
		// EOF
		if (t->index == t->length)
			break;
		// Ignored tags
		else if (t->document[t->index] == '<')
			{
			t->index++;
			while (t->index < t->length && t->document[t->index] != '>')
				t->index++;
			t->index++;
			continue;
			}
		else
			return fucs_parser_next(t, buffer);
		}

	return END;
	}

#endif

