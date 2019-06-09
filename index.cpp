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

void index_write(char const *filename, char *buffer, dynamic_array<std::pair<char *, size_t>> *docNos, hash_table<posting, uint32_t> *dictionary)
	{
	FILE *fh = fopen(filename, "w");
	if (fh == NULL)
		{
		fprintf(stderr, "ERROR: Failed to open index.dat for writing\n");
		exit(1);
		}

	// Write to output buffer
	size_t offset = 8;

	((size_t *)&buffer[offset])[0] = docNos->length;
	size_t docNos_offset = offset + sizeof(size_t);
	offset += sizeof(size_t) + docNos->length * (sizeof(char *) + sizeof(size_t));
	for (size_t i = 0; i < docNos->length; i++)
		{
		((size_t *)&buffer[docNos_offset])[0] = offset;
		((size_t *)&buffer[docNos_offset])[1] = docNos->store[i].second;
		docNos_offset += sizeof(size_t) * 2;

		offset += string_copy_c(&buffer[offset], docNos->store[i].first);
		}

	((size_t *)buffer)[0] = offset;
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

	char tok_buffer[260];
	struct string *file = file_slurp_c(argv[1]);
	tokenizer *tok = new tokenizer(file->str, file->bytes);
	enum token_type token;

	dynamic_array<std::pair<char *, size_t>> *docNos = new dynamic_array<std::pair<char *, size_t>>();
	hash_table<posting, uint32_t> *dictionary = new hash_table<posting, uint32_t>();
	uint32_t docI = 0;
	do
		{
		token = tok->next(tok_buffer);
		if (token == DOCNO)
			{
			docNos->append(std::make_pair(string_s_dup(tok_buffer), 0));
			docI++;
			}
		else if (token == WORD)
			{
			docNos->back()->second++;
			dictionary->insert(tok_buffer, docI);
			}
		} while (token != END);

	index_write("index.dat", file->str, docNos, dictionary);

	return 0;
	}
