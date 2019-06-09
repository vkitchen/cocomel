#include <stdint.h>
#include <ctype.h>
#include "tokenizer.h"

static inline int prefix(const char *pre, const char *str)
	{
	while (*pre)
		if (*pre++ != *str++)
			return 0;
	return 1;
	}

static inline char lower(char c)
	{
	if (c < 'a')
		c += 'a' - 'A';

	return c;
	}

static inline char upper(char c)
	{
	if ('Z' < c)
		c -= 'a' - 'A';
	
	return c;
	}

tokenizer::tokenizer(char *doc, size_t len)
	{
	document = doc;
	length = len;
	index = 0;
	}

enum token_type tokenizer::next(char *buffer)
	{
	for (;;)
		{
		// Whitespace
		while(index < length && isspace(document[index]))
			index++;
		// EOF
		if (index == length)
			break;
		// Doc ID
		else if (prefix("<DOCNO>", &document[index]))
			{
			index += sizeof("<DOCNO>");

			while(index < length && isspace(document[index]))
				index++;

			int i = 0;
			while (i < 256 && i + index < length && document[index + i] != '<' && !isspace(document[index + i]))
				{
				buffer[i+4] = document[index + i];
				i++;
				}
			((uint32_t *)buffer)[0] = i;
			buffer[i+4] = '\0';

			index += i;

			return DOCNO;
			}
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
		else if (isdigit(document[index]))
			{
			int i = 0;
			while (i < 256 && i + index < length && isdigit(document[index + i]))
				{
				buffer[i+4] = document[index + i];
				i++;
				}
			((uint32_t *)buffer)[0] = i;
			buffer[i+4] = '\0';

			index += i;

			return WORD;
			}
		// Word
		else if (isalpha(document[index]))
			{
			int i = 0;
			while (i < 256 && i + index < length && isalpha(document[index + i]))
				{
				buffer[i+4] = upper(document[index + i]);
				i++;
				}
			((uint32_t *)buffer)[0] = i;
			buffer[i+4] = '\0';

			index += i;

			return WORD;
			}
		// Something else we don't want
		else
			index++;
		}

	return END;
	}
