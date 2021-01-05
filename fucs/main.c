#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "file.h"
#include "fucs.h"
#include "tokenizer.h"

int all_is_whitespace(char *str)
	{
	for (int i = 0; i < strlen(str); i++)
		if (!isspace(str[i]))
			return 0;
	return 1;
	}

char *lowercase(char *str)
	{
	for (int i = 0; i < strlen(str); i++)
		if (isalpha(str[i]))
			str[i] = tolower(str[i]);
	return str;
	}

int main(int argc, char *argv[])
	{
	char *document = NULL;
	if (argc != 2)
		{
		fprintf(stderr, "Please provide a file\n");
		exit(1);
		}
	size_t file_length = file_slurp(argv[1], &document);
	if (file_length == 0)
		{
		fprintf(stderr, "File could not be read\n");
		exit(1);
		}
//	fucs_print();

	char tok_buffer_store[516]; // Provide underlying storage for tok_buffer
	struct str tok_buffer;
	tok_buffer.store = tok_buffer_store;

	struct tokenizer *tok = fucs_parser_new(document);
	enum token_type token;
	while ((token = tokenizer_next(tok, tok_buffer)) == WORD)
		if (!all_is_whitespace(str_c(tok_buffer)))
			printf("%s\n", lowercase(str_c(tok_buffer)));
	return 0;
	}
