/*
	SEARCH_CLI.C
	------------
	Copyright (c) 2020, 2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#include <stdio.h>
#include "config.h"
#include "dynamic_array_kv_32.h"
#include "dynamic_array_kv_64.h"
#include "file.h"
#include "search.h"

void read_snippets_header(FILE *fh, struct dynamic_array_kv_32 *offsets)
	{
	fseek(fh, -sizeof(uint32_t), SEEK_END);

	fread(&offsets->length, sizeof(uint32_t), 1, fh);
	offsets->capacity = offsets->length;

	fseek(fh, -(sizeof(uint32_t) + 2 * offsets->length * sizeof(uint32_t)), SEEK_END);

	offsets->store = malloc(2 * offsets->length * sizeof(uint32_t));
	fread(offsets->store, sizeof(uint32_t), 2 * offsets->length, fh);
	}

void print_snippet(FILE *fh, struct dynamic_array_kv_32 *offsets, size_t index)
	{
	size_t doc_len = dynamic_array_kv_32_at(offsets, index)[1];
	char *doc = malloc(doc_len + 1);
	fseek(fh, dynamic_array_kv_32_at(offsets, index)[0], SEEK_SET);
	fread(doc, sizeof(char), doc_len, fh);
	doc[doc_len] = '\0';
	printf("Snippet: %.300s\n", doc);
	}

int main(void)
	{

	char *index;
	file_slurp("index.dat", &index);

	if (!file_exists("snippets.dat"))
		{
		fputs("ERROR: snippets file missing\n", stderr);
		exit(1);
		}

	FILE *snippets_fh;
	struct dynamic_array_kv_32 snippet_offsets;

	if (snippets_enabled)
		{
		snippets_fh = fopen("snippets.dat", "rb");
		if (snippets_fh == NULL)
			{
			fprintf(stderr, "ERROR: Failed to open snippets.dat for reading\n");
			exit(1);
			}

		read_snippets_header(snippets_fh, &snippet_offsets);
		}

	// Decode index
	struct dynamic_array_kv_32 docNos;
	dynamic_array_kv_32_init(&docNos);
	docNos.length = ((uint32_t *)index)[1];
	docNos.store = (uint32_t *)&index[2 * sizeof(uint32_t)];

	// Accept input
	char line[1024];
	if (fgets(line, sizeof(line), stdin) != NULL)
		{
		struct dynamic_array_kv_64 *result_list = search(index, line);

		if (result_list == NULL)
			{
			printf("No results\n");
			exit(0);
			}

		for (size_t i = 0; i < result_list->length; i++)
			{
			size_t docId = dynamic_array_kv_64_at(result_list, i)[0] - 1;
			double rsv = *(double *)&dynamic_array_kv_64_at(result_list, i)[1];
			printf("%s %f\n", index + dynamic_array_kv_32_at(&docNos, docId)[0], rsv);
			if (snippets_enabled)
				print_snippet(snippets_fh, &snippet_offsets, docId);
			}

		}

	return 0;
	}

