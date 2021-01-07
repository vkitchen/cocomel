/*
	INDEX.C
	-------
	Copyright (c) 2018, 2019, 2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#include <stdio.h>
#include <stdint.h>
#include "dynamic_array_64.h"
#include "dynamic_array_kv_32.h"
#include "dynamic_array_kv_64.h"
#include "posting.h"
#include "hash_table.h"
#include "tokenizer.h"
#include "tokenizer_zlib.h"
#include "str.h"
#include "file.h"

const char *usage = "\
Usage: index [option] [file ...]\n\
\n\
Options:\n\
  --snippets  Enable snippet support in the index\
";

void index_write(char const *filename, char *buffer, struct dynamic_array_kv_64 *docNos, struct hash_table *dictionary)
	{
	FILE *fh = fopen(filename, "w");
	if (fh == NULL)
		{
		fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);
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

// TODO merge this into the main index
void snippets_write(char const *filename, struct dynamic_array_64 *tokenized_docs)
	{
	FILE *fh = fopen(filename, "w");
	if (fh == NULL)
		{
		fprintf(stderr, "ERROR: Failed to open %s for writing\n", filename);
		exit(1);
		}

	uint32_t offset = 0;

	struct dynamic_array_kv_32 offsets;
	dynamic_array_kv_32_init(&offsets);

	for (size_t i = 0; i < tokenized_docs->length; i++)
		{
		struct str doc;
		doc.store = (char *)tokenized_docs->store[i];

		if (doc.store == NULL)
			{
			dynamic_array_kv_32_append(&offsets, offset, 0);
			continue;
			}

		fwrite(str_c(doc), sizeof(char), str_len(doc), fh);

		dynamic_array_kv_32_append(&offsets, offset, str_len(doc));
		offset += str_len(doc);
		}

	fwrite(offsets.store, sizeof(uint32_t), offsets.length * 2, fh);
	fwrite(&offsets.length, sizeof(uint32_t), 1, fh);
	fclose(fh);
	}

int main(int argc, char **argv)
	{
	int snippets_enabled = 0;
	int first_file_arg = 1;

	if (argc < 2)
		{
		puts(usage);
		return 1;
		}

	if (string_cmp(argv[1], "--snippets") == 0)
		{
		snippets_enabled = 1;
		first_file_arg++;
		}

	char tok_buffer_store[512 + 2 * sizeof(uint32_t)]; // Provide underlying storage for tok_buffer
	struct str tok_buffer;
	tok_buffer.store = tok_buffer_store;
	enum token_type token;

	// Doc names and lengths
	struct dynamic_array_kv_64 docNos;
	dynamic_array_kv_64_init(&docNos);
	// Documents proper
	struct dynamic_array_64 tokenized_docs;
	dynamic_array_64_init(&tokenized_docs);
	// Postings
	struct hash_table dictionary;
	hash_table_init(&dictionary);

	struct tokenizer tok;
	struct tokenizer_zlib tok_zlib;

	for (int i = first_file_arg; i < argc; i++)
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
					if (snippets_enabled)
						dynamic_array_64_append(&tokenized_docs, (uint64_t)NULL);
					}
				else if (token == WORD)
					{
					dynamic_array_kv_64_back(&docNos)[1]++;
					hash_table_insert(&dictionary, tok_buffer, docNos.length);
					if (snippets_enabled)
						{
						if ((char *)*dynamic_array_64_back(&tokenized_docs) == NULL)
							{
							struct str doc = str_new(1024);
							doc = str_append(doc, tok_buffer);
							*dynamic_array_64_back(&tokenized_docs) = (uint64_t)doc.store;
							}
						else
							{
							struct str doc;
							doc.store = (char *)*dynamic_array_64_back(&tokenized_docs);
							doc = str_append_c(doc, " ");
							doc = str_append(doc, tok_buffer);
							*dynamic_array_64_back(&tokenized_docs) = (uint64_t)doc.store;
							}
						}
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
					if (snippets_enabled)
						dynamic_array_64_append(&tokenized_docs, (uint64_t)NULL);
					}
				else if (token == WORD)
					{
					dynamic_array_kv_64_back(&docNos)[1]++;
					hash_table_insert(&dictionary, tok_buffer, docNos.length);
					if (snippets_enabled)
						{
						if ((char *)*dynamic_array_64_back(&tokenized_docs) == NULL)
							{
							struct str doc = str_new(1024);
							doc = str_append(doc, tok_buffer);
							*dynamic_array_64_back(&tokenized_docs) = (uint64_t)doc.store;
							}
						else
							{
							struct str doc;
							doc.store = (char *)*dynamic_array_64_back(&tokenized_docs);
							doc = str_append_c(doc, " ");
							doc = str_append(doc, tok_buffer);
							*dynamic_array_64_back(&tokenized_docs) = (uint64_t)doc.store;
							}
						}
					}
				} while (token != END);
			}
		}

	char *out_buffer = (char *)malloc(256*1024*1024);
	if (out_buffer == NULL)
		{
		fprintf(stderr, "Failed to allocate output buffer\n");
		exit(1);
		}
	index_write("index.dat", out_buffer, &docNos, &dictionary);
	if (snippets_enabled)
		snippets_write("snippets.dat", &tokenized_docs);

	return 0;
	}
