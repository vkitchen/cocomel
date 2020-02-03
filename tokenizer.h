#ifndef TOKENIZER_H
#define TOKENIZER_H

#include "char.h"
#include "memory.h"
#include "str.h"

enum token_type {DOCNO, WORD, END};

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
		// Doc ID
		else if (string_prefix("<DOCNO>", &t->document[t->index]))
			{
			t->index += sizeof("<DOCNO>");

			while(t->index < t->length && char_isspace(t->document[t->index]))
				t->index++;

			int i = 0;
			char *buf = str_c(buffer);
			while (i < 256 && i + t->index < t->length && t->document[t->index + i] != '<' && !char_isspace(t->document[t->index + i]))
				{
				buf[i] = t->document[t->index + i];
				i++;
				}
			buf[i] = '\0';
			str_resize(buffer, i);

			t->index += i;

			return DOCNO;
			}
		// Ignored tags
		else if (t->document[t->index] == '<')
			{
			t->index++;
			while (t->index < t->length && t->document[t->index] != '>')
				t->index++;
			t->index++;
			continue;
			}
		// Number
		else if (char_isdigit(t->document[t->index]))
			{
			int i = 0;
			char *buf = str_c(buffer);
			while (i < 256 && i + t->index < t->length && char_isdigit(t->document[t->index + i]))
				{
				buf[i] = t->document[t->index + i];
				i++;
				}
			buf[i] = '\0';
			str_resize(buffer, i);

			t->index += i;

			return WORD;
			}
		// Word
		else if (char_isalpha(t->document[t->index]))
			{
			int i = 0;
			char *buf = str_c(buffer);
			while (i < 256 && i + t->index < t->length && char_isalpha(t->document[t->index + i]))
				{
				buf[i] = char_tolower(t->document[t->index + i]);
				i++;
				}
			buf[i] = '\0';
			str_resize(buffer, i);

			t->index += i;

			return WORD;
			}
		// Something else we don't want
		else
			t->index++;
		}

	return END;
	}

#endif

