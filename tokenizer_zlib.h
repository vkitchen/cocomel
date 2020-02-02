#ifndef TOKENIZER_ZLIB_H
#define TOKENIZER_ZLIB_H

#include <zlib.h>
#include "tar.h"
#include "str.h"

struct tokenizer_zlib
	{
	char header_buffer[sizeof(struct tar_header)];
	size_t index;
	size_t length;
	char *document;
	size_t document_max;
	gzFile fd;
	};

void tokenizer_zlib_init(struct tokenizer_zlib *t, char *filename);
void tokenizer_zlib_cleanup(struct tokenizer_zlib *t);
enum token_type tokenizer_zlib_next(struct tokenizer_zlib *t, struct str buffer);

#endif

