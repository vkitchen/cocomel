#include <stdio.h>
#include <stdint.h>
#include "dynamic_array_kv_64.h"
#include "posting.h"
#include "hash_table.h"
#include "tokenizer.h"
#include "tokenizer_zlib.h"
#include "str.h"
#include "file.h"

const char *usage = "\
Usage: index [file ...]\
";

void index_write(char const *filename, char *buffer, struct dynamic_array_kv_64 *docNos, struct hash_table *dictionary)
	{
	FILE *fh = fopen(filename, "w");
	if (fh == NULL)
		{
		fprintf(stderr, "ERROR: Failed to open index.dat for writing\n");
		exit(1);
		}

	// Write to output buffer
	uint32_t offset = sizeof(uint32_t) * 2;

	((uint32_t *)buffer)[1] = docNos->length;
	uint32_t docNos_offset = offset;
	offset += docNos->length * sizeof(uint32_t) * 2;
	for (size_t i = 0; i < docNos->length; i++)
		{
		((uint32_t *)&buffer[docNos_offset])[0] = offset;
		((uint32_t *)&buffer[docNos_offset])[1] = dynamic_array_kv_64_at(docNos, i)[1];
		docNos_offset += sizeof(uint32_t) * 2;

		offset += string_copy(&buffer[offset], (char *)dynamic_array_kv_64_at(docNos, i)[0]);
		}

	((uint32_t *)buffer)[0] = offset;
        offset += hash_table_write(dictionary, &buffer[offset]);

	fwrite(buffer, sizeof(char), offset, fh);
	fclose(fh);
	}

int main(int argc, char **argv)
	{
	if (argc < 2)
		{
		puts(usage);
		return 1;
		}

	char tok_buffer_store[516]; // Provide underlying storage for tok_buffer
	struct str tok_buffer;
	tok_buffer.store = tok_buffer_store;
	enum token_type token;

	struct dynamic_array_kv_64 docNos;
	dynamic_array_kv_64_init(&docNos);
	struct hash_table dictionary;
	hash_table_init(&dictionary);

	struct tokenizer tok;
	struct tokenizer_zlib tok_zlib;

	for (int i = 1; i < argc; i++)
		{
		if (string_suffix(".tar.gz", argv[i]))
			{
			tokenizer_zlib_init(&tok_zlib, argv[i]);
			do
				{
				token = tokenizer_zlib_next(&tok_zlib, tok_buffer);
				if (token == DOCNO)
					{
					if (docNos.length > 0 && docNos.length % 10000 == 0)
						fprintf(stderr, "%d Documents\n", docNos.length);
					dynamic_array_kv_64_append(&docNos, (uint64_t)str_dup_c(tok_buffer), 0);
					}
				else if (token == WORD)
					{
					dynamic_array_kv_64_back(&docNos)[1]++;
					hash_table_insert(&dictionary, tok_buffer, docNos.length);
					}
				} while (token != END);

			tokenizer_zlib_cleanup(&tok_zlib);
			}
		else
			{
			char *file;
			size_t file_length = file_slurp(argv[i], &file);
			tokenizer_init(&tok, file, file_length);
			do
				{
				token = tokenizer_next(&tok, tok_buffer);
				if (token == DOCNO)
					{
					if (docNos.length > 0 && docNos.length % 10000 == 0)
						fprintf(stderr, "%d Documents\n", docNos.length);
					dynamic_array_kv_64_append(&docNos, (uint64_t)str_dup_c(tok_buffer), 0);
					}
				else if (token == WORD)
					{
					dynamic_array_kv_64_back(&docNos)[1]++;
					hash_table_insert(&dictionary, tok_buffer, docNos.length);
					}
				} while (token != END);
			}
		}
	char *out_buffer = (char *)malloc(512*1024*1024);
	index_write("index.dat", out_buffer, &docNos, &dictionary);

	return 0;
	}
