#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "tokenizer.h"
#include "dynamic_array_64.h"
#include "dynamic_array_kv_32.h"
#include "dynamic_array_kv_64.h"
#include "str.h"
#include "file.h"
#include "vbyte.h"
#include "posting.h"
#include "hash_table.h"
#include "search.h"

static struct dynamic_array_kv_64 *intersect_postings(struct dynamic_array_64 *postings)
	{
	struct dynamic_array_kv_64 *result = malloc(sizeof(struct dynamic_array_kv_64));
	dynamic_array_kv_64_init(result);

	size_t *indexes = (size_t *)malloc(sizeof(size_t) * postings->length);
	for (size_t i = 0; i < postings->length; i++)
		indexes[i] = 0;

	while (indexes[0] < ((struct dynamic_array_kv_64 *)postings->store[0])->length)
		{
		size_t id = dynamic_array_kv_64_at((struct dynamic_array_kv_64 *)postings->store[0], indexes[0])[0];
		int canAdd = 1;
		for (size_t i = 1; i < postings->length; i++)
			{
			while (indexes[i] < ((struct dynamic_array_kv_64 *)postings->store[i])->length && dynamic_array_kv_64_at((struct dynamic_array_kv_64 *)postings->store[i], indexes[i])[0] < id)
				indexes[i]++;
			if (indexes[i] == ((struct dynamic_array_kv_64 *)postings->store[i])->length)
				return result;
			if (dynamic_array_kv_64_at((struct dynamic_array_kv_64 *)postings->store[i], indexes[i])[0] != id)
				canAdd = 0;
			}
		if (canAdd)
			{
			double rsv = 0;
			for (size_t i = 0; i < postings->length; i++)
				rsv += dynamic_array_kv_64_at((struct dynamic_array_kv_64 *)postings->store[i], indexes[i])[1];
			dynamic_array_kv_64_append(result, id, rsv);
			}
		indexes[0]++;
		}

	return result;
	}

static void results_sort(struct dynamic_array_kv_64 *results)
	{
	for (size_t i = 1; i < results->length; i++)
		{
		uint64_t tmp_a = dynamic_array_kv_64_at(results, i)[0];
		// non-negative floats sort like ints. avoid the cast here
		uint64_t tmp_b = dynamic_array_kv_64_at(results, i)[1];

		size_t j = i;
		while (j > 0 && tmp_b > dynamic_array_kv_64_at(results, j-1)[1])
			{
			dynamic_array_kv_64_at(results, j)[0] = dynamic_array_kv_64_at(results, j-1)[0];
			dynamic_array_kv_64_at(results, j)[1] = dynamic_array_kv_64_at(results, j-1)[1];
			j--;
			}
		dynamic_array_kv_64_at(results, j)[0] = tmp_a;
		dynamic_array_kv_64_at(results, j)[1] = tmp_b;
		}
	}

static void rank(struct dynamic_array_kv_64 *posting, struct dynamic_array_kv_32 *docNos, double avgdl)
	{
	double wt = log2((docNos->length - posting->length + 0.5) / (posting->length + 0.5));
	for (size_t i = 0; i < posting->length; i++)
		{
		size_t docId = dynamic_array_kv_64_at(posting, i)[0] - 1;
		size_t tf = dynamic_array_kv_64_at(posting, i)[1];
		double docLength = (size_t)dynamic_array_kv_32_at(docNos, docId)[1];
		double K = 1.2 * (0.25 + 0.75 * docLength / avgdl);
		double w = wt * 2.2 * tf / (K + tf);
		dynamic_array_kv_64_at(posting, i)[1] = *(uint64_t *)&w;
		}
	}

struct dynamic_array_kv_64 *search(char *index, char *line)
	{
	double avgdl = 0;

	// Decode index
	struct dynamic_array_kv_32 docNos;
	dynamic_array_kv_32_init(&docNos);
	docNos.length = ((uint32_t *)index)[1];
	docNos.store = (uint32_t *)&index[2 * sizeof(uint32_t)];

	size_t dict_offset = ((uint32_t *)index)[0];
	struct hash_table dictionary;
	hash_table_init(&dictionary);
	hash_table_read(&dictionary, &index[dict_offset]);

	// Find average document length
	for (size_t i = 0; i < docNos.length; i++)
		avgdl += dynamic_array_kv_32_at(&docNos, i)[1];
	avgdl /= docNos.length;

	char tok_buffer_store[260]; // Provide underlying storage for tok_buffer
	struct str tok_buffer;
//	str_init(&tok_buffer);
	tok_buffer.store = tok_buffer_store;

	enum token_type token;
	struct tokenizer tok;

	// Perform the search
	struct dynamic_array_64 terms;
	dynamic_array_64_init(&terms);
	tokenizer_init(&tok, line, strlen(line));
	do
		{
		token = tokenizer_next(&tok, tok_buffer);
		if (token == WORD)
			{
			string_tolower(str_c(tok_buffer));
			dynamic_array_64_append(&terms, (uint64_t)str_dup_c(tok_buffer));
			}
		} while (token != END);

	if (terms.length == 0)
		exit(0);

	struct dynamic_array_64 postings;
	dynamic_array_64_init(&postings);

	// Find results for strings
	for (size_t i = 0; i < terms.length; i++)
		{
		struct posting *post_compressed = hash_table_find(&dictionary, (char *)terms.store[i]);
		if (post_compressed == NULL)
			return NULL;
		else
			{
			struct dynamic_array_kv_64 *post = posting_decompress(post_compressed);
			rank(post, &docNos, avgdl);
			dynamic_array_64_append(&postings, (uint64_t)post);
			}
		}

	struct dynamic_array_kv_64 *result_list = intersect_postings(&postings);

	results_sort(result_list);

	return result_list;
	}

