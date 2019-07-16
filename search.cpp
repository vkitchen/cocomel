#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <utility>
#include <math.h>
#include "tokenizer.h"
#include "dynamic_array.h"
#include "str.h"
#include "file.h"
#include "vbyte.h"
#include "posting.h"
#include "hash_table.h"

dynamic_array<std::pair<size_t, double>> *intersect_postings(dynamic_array<dynamic_array<std::pair<size_t, double>> *> *postings)
	{
	dynamic_array<std::pair<size_t, double>> *result = new dynamic_array<std::pair<size_t, double>>();

	size_t *indexes = (size_t *)malloc(sizeof(size_t) * postings->length);
	for (size_t i = 0; i < postings->length; i++)
		indexes[i] = 0;

	while (indexes[0] < postings->store[0]->length)
		{
		size_t id = postings->store[0]->store[indexes[0]].first;
		bool canAdd = true;
		for (size_t i = 1; i < postings->length; i++)
			{
			while (indexes[i] < postings->store[i]->length && postings->store[i]->store[indexes[i]].first < id)
				indexes[i]++;
			if (indexes[i] == postings->store[i]->length)
				return result;
			if (postings->store[i]->store[indexes[i]].first != id)
				canAdd = false;
			}
		if (canAdd)
			{
			double rsv = 0;
			for (size_t i = 0; i < postings->length; i++)
				rsv += postings->store[i]->store[indexes[i]].second;
			result->append(std::make_pair(id, rsv));
			}
		indexes[0]++;
		}

	return result;
	}

void results_sort(dynamic_array<std::pair<size_t, double>> *results)
	{
	for (size_t i = 1; i < results->length; i++)
		{
		std::pair<size_t, double> tmp = results->store[i];
		size_t j = i;
		while (j > 0 && tmp.second > results->store[j-1].second)
			{
			results->store[j] = results->store[j-1];
			j--;
			}
		results->store[j] = tmp;
		}
	}

void rank(dynamic_array<std::pair<size_t, double>> *posting, dynamic_array<std::pair<uint32_t, uint32_t>> *docNos, double avgdl)
	{
	double wt = log2((docNos->length - posting->length + 0.5) / (posting->length + 0.5));
	for (size_t i = 0; i < posting->length; i++)
		{
		size_t docId = posting->store[i].first - 1;
		size_t tf = posting->store[i].second;
		double docLength = (size_t)docNos->store[docId].second;
		double K = 1.2 * (0.25 + 0.75 * docLength / avgdl);
		double w = wt * 2.2 * tf / (K + tf);
		posting->store[i].second = w;
		}
	}

int main(void)
	{
	double avgdl = 0;

	char *index;
	file_slurp("index.dat", &index);

	// Decode index
	dynamic_array<std::pair<uint32_t, uint32_t>> *docNos = new dynamic_array<std::pair<uint32_t, uint32_t>>();
	docNos->length = ((uint32_t *)index)[1];
	docNos->store = (std::pair<uint32_t, uint32_t> *)&index[2 * sizeof(uint32_t)];

	size_t dict_offset = ((uint32_t *)index)[0];
	hash_table<posting, uint32_t> *dictionary = hash_table<posting, uint32_t>::read(&index[dict_offset]);

	// Find average document length
	for (size_t i = 0; i < docNos->length; i++)
		avgdl += docNos->store[i].second;
	avgdl /= docNos->length;

	// Accept input
	char line[1024];
	char tok_buffer_store[260]; // Provide underlying storage for tok_buffer
	str tok_buffer(tok_buffer_store);
	enum token_type token;
	tokenizer tok;
	while (fgets(line, sizeof(line), stdin) != NULL)
		{
		dynamic_array<char *> *terms = new dynamic_array<char *>();
		tok.init(line, strlen(line));
		do
			{
			token = tok.next(tok_buffer);
			if (token == WORD)
				{
				string_tolower(tok_buffer.c_str());
				terms->append(tok_buffer.c_dup());
				}
			} while (token != END);

		if (terms->length == 0)
			exit(0);

		dynamic_array<dynamic_array<std::pair<size_t, double>> *> postings;

		// Find results for strings
		for (size_t i = 0; i < terms->length; i++)
			{
			terms->store[i] = (char *)dictionary->find((char *)terms->store[i]);
			if (terms->store[i] == NULL)
				{
				printf("No results\n");
				exit(0);
				}
			else
				{
				dynamic_array<std::pair<size_t, double>> *post = ((posting *)terms->store[i])->decompress();
				rank(post, docNos, avgdl);
				postings.append(post);
				}
			}

		dynamic_array<std::pair<size_t, double>> *result_list = intersect_postings(&postings);

		results_sort(result_list);

		for (size_t i = 0; i < result_list->length; i++)
			{
			size_t docId = result_list->store[i].first - 1;
			double rsv = result_list->store[i].second;
			printf("%s %f\n", index + docNos->store[docId].first, rsv);
			}

		}

	return 0;
	}
