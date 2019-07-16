#include <stdlib.h>

#include <stdio.h>

#include "tokenizer.h"
#include "tokenizer_zlib.h"

enum token_type tokenizer_zlib::next_file(str buffer)
	{
	struct tar_header *tar = (struct tar_header *)header_buffer;
	char file_size[13];

	index = 0;

	for (;;)
		{
		if (gzeof(fd))
			return END;

		gzread(fd, header_buffer, sizeof(header_buffer));

		string_n_copy(file_size, (char *)&tar->size, 13);
		file_size[12] = '\0';
		length = strtol(file_size, NULL, 8);

		if (length == 0)
			continue;

		size_t ncopied = string_n_copy(buffer.c_str(), (char *)&tar->name, 100);
		buffer.resize(ncopied);

		break;
		}

	if (document == NULL)
		{
		document_max = length + 1;
		document = (char *)malloc(document_max);
		}
	else if (length > document_max)
		{
		document_max = length + 1;
		document = (char *)realloc(document, document_max);
		}

	gzread(fd, document, length);

	document[length] = '\0';

	if (length % 512)
		gzseek(fd, 512 - (length % 512), SEEK_CUR);

	return DOCNO;
	}

enum token_type tokenizer_zlib::next(str buffer)
	{
	for (;;)
		{
		// Whitespace
		while(index < length && char_isspace(document[index]))
			index++;
		// Decompress next chunk
		if (index >= length)
			return next_file(buffer); // *TODO* return DOCNO && EOF
		// EOF
		if (index >= length)
			break;
		// Ignored tags
		else if (document[index] == '<')
			{
			index++;
			while (index < length && document[index] != '>')
				index++;
			index++;
			continue;
			}
		// Number
		else if (char_isdigit(document[index]))
			{
			int i = 0;
			while (i < 256 && i + index < length && char_isdigit(document[index + i]))
				{
				buffer[i] = document[index + i];
				i++;
				}
			buffer[i] = '\0';
			buffer.resize(i);

			index += i;

			return WORD;
			}
		// Word
		else if (char_isalpha(document[index]))
			{
			int i = 0;
			while (i < 256 && i + index < length && char_isalpha(document[index + i]))
				{
				buffer[i] = char_tolower(document[index + i]);
				i++;
				}
			buffer[i] = '\0';
			buffer.resize(i);

			index += i;

			return WORD;
			}
		// Something else we don't want
		else
			index++;
		}

	return END;
	}
