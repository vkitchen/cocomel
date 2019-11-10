#include <stdlib.h>
#include <stdio.h>
#include "char.h"
#include "string.h"
#include "tokenizer.h"

#include "tokenizer_zlib.h"

void tokenizer_zlib_init(struct tokenizer_zlib *t, char *filename)
	{
	t->index = 0;
	t->length = 0;
	t->document = NULL;
	t->document_max = 0;
	t->fd = gzopen(filename, "rb");
	}

void tokenizer_zlib_cleanup(struct tokenizer_zlib *t)
	{
	gzclose(t->fd);
	}

static enum token_type next_file(struct tokenizer_zlib *t, struct str buffer)
	{
	struct tar_header *tar = (struct tar_header *)t->header_buffer;
	char file_size[13];

	t->index = 0;

	for (;;)
		{
		if (gzeof(t->fd))
			return END;

		gzread(t->fd, t->header_buffer, sizeof(t->header_buffer));

		string_n_copy(file_size, (char *)&tar->size, 13);
		file_size[12] = '\0';
		t->length = strtol(file_size, NULL, 8);

		if (t->length == 0)
			continue;

		size_t ncopied = 0;
		if (*(char *)&tar->prefix) {
			ncopied += string_n_copy(str_c(buffer), (char *)&tar->prefix, 156);
			str_c(buffer)[ncopied] = '/';
			ncopied++;
		}
		ncopied += string_n_copy(&str_c(buffer)[ncopied], (char *)&tar->name, 101);
		str_resize(buffer, ncopied);

		break;
		}

	if (t->document == NULL)
		{
		t->document_max = t->length + 1;
		t->document = (char *)malloc(t->document_max);
		}
	else if (t->length > t->document_max)
		{
		t->document_max = t->length + 1;
		t->document = (char *)realloc(t->document, t->document_max);
		}

	gzread(t->fd, t->document, t->length);

	t->document[t->length] = '\0';

	if (t->length % 512)
		gzseek(t->fd, 512 - (t->length % 512), SEEK_CUR);

	return DOCNO;
	}

enum token_type tokenizer_zlib_next(struct tokenizer_zlib *t, struct str buffer)
	{
	for (;;)
		{
		// Whitespace
		while(t->index < t->length && char_isspace(t->document[t->index]))
			t->index++;
		// Decompress next chunk
		if (t->index >= t->length)
			return next_file(t, buffer); // *TODO* return DOCNO && EOF
		// EOF
		if (t->index >= t->length)
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
