#include <stdio.h>
#include <utility>
#include "dynamic_array.h"
#include "posting.h"
#include "hash_table.h"
#include "tokenizer.h"
#include "str.h"
#include "file.h"

const char *usage = "\
Usage: index [file]\
";

void index_write(char const *filename, char *buffer, dynamic_array<std::pair<char *, uint32_t>> *docNos, hash_table<posting, uint32_t> *dictionary)
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
		((uint32_t *)&buffer[docNos_offset])[1] = docNos->store[i].second;
		docNos_offset += sizeof(uint32_t) * 2;

		offset += string_copy(&buffer[offset], docNos->store[i].first);
		}

	((uint32_t *)buffer)[0] = offset;
        offset += dictionary->write(&buffer[offset]);

	fwrite(buffer, sizeof(char), offset, fh);
	fclose(fh);
	}

int main(int argc, char **argv)
	{
	if (argc != 2)
		{
		puts(usage);
		return 1;
		}

	char tok_buffer_store[260]; // Provide underlying storage for tok_buffer
	str tok_buffer(tok_buffer_store);
	char *file;
	size_t file_length = file_slurp(argv[1], &file);
	tokenizer *tok = new tokenizer(file, file_length);
	enum token_type token;

	dynamic_array<std::pair<char *, uint32_t>> docNos;
	hash_table<posting, uint32_t> dictionary;
	do
		{
		token = tok->next(tok_buffer);
		if (token == DOCNO)
			docNos.append(std::make_pair(tok_buffer.c_dup(), 0));
		else if (token == WORD)
			{
			docNos.back()->second++;
			dictionary.insert(tok_buffer, docNos.length);
			}
		} while (token != END);

	index_write("index.dat", file, &docNos, &dictionary);

	return 0;
	}
