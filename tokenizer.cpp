#include <stdint.h>
#include "tokenizer.h"

enum token_type tokenizer::next(str buffer)
	{
	for (;;)
		{
		// Whitespace
		while(index < length && char_isspace(document[index]))
			index++;
		// EOF
		if (index == length)
			break;
		// Doc ID
		else if (string_prefix("<DOCNO>", &document[index]))
			{
			index += sizeof("<DOCNO>");

			while(index < length && char_isspace(document[index]))
				index++;

			int i = 0;
			while (i < 256 && i + index < length && document[index + i] != '<' && !char_isspace(document[index + i]))
				{
				buffer[i] = document[index + i];
				i++;
				}
			buffer[i] = '\0';
			buffer.resize(i);

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
