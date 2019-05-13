#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <utility>
#include <math.h>
#include "dynamic_array.h"
#include "string2.h"
#include "file.h"
#include "vbyte.h"
#include "vector.h"
#include "vector_kv.h"
#include "posting.h"

dynamic_array<std::pair<size_t, double>> *intersect_postings(dynamic_array<dynamic_array<std::pair<size_t, double>> *> *postings) {
	dynamic_array<std::pair<size_t, double>> *result = new dynamic_array<std::pair<size_t, double>>();

	size_t *indexes = (size_t *)malloc(sizeof(size_t) * postings->length);
	for (size_t i = 0; i < postings->length; i++) {
		indexes[i] = 0;
	}

	while (indexes[0] < postings->store[0]->length) {
		size_t id = postings->store[0]->store[indexes[0]].first;
		bool canAdd = true;
		for (size_t i = 1; i < postings->length; i++) {
			while (indexes[i] < postings->store[i]->length && postings->store[i]->store[indexes[i]].first < id)
				indexes[i]++;
			if (indexes[i] == postings->store[i]->length)
				return result;
			if (postings->store[i]->store[indexes[i]].first != id)
				canAdd = false;
		}
		if (canAdd) {
			double rsv = 0;
			for (size_t i = 0; i < postings->length; i++)
				rsv += postings->store[i]->store[indexes[i]].second;
			result->append(std::make_pair(id, rsv));
		}
		indexes[0]++;
	}

	return result;
}

void results_sort(dynamic_array<std::pair<size_t, double>> *results) {
	for (size_t i = 1; i < results->length; i++) {
		std::pair<size_t, double> tmp = results->store[i];
		size_t j = i;
		while (j > 0 && tmp.second > results->store[j-1].second) {
			results->store[j] = results->store[j-1];
			j--;
		}
		results->store[j] = tmp;
	}
}

void rank(dynamic_array<std::pair<size_t, double>> *posting, struct vector_kv *docNos, double avgdl) {
	double wt = log2((docNos->length - posting->length + 0.5) / (posting->length + 0.5));
	for (size_t i = 0; i < posting->length; i++) {
		size_t docId = posting->store[i].first;
		size_t tf = posting->store[i].second;
		double docLength = (size_t)docNos->store[docId*2 + 1];
		double K = 1.2 * (0.25 + 0.75 * docLength / avgdl);
		double w = wt * 2.2 * tf / (K + tf);
		posting->store[i].second = w;
	}
}

int main(void) {
	double avgdl = 0;

	struct string *index = file_slurp_c("index.dat");

	// Decode index
	struct vector_kv *docNos = (struct vector_kv *)malloc(sizeof(struct vector_kv));
	docNos->length = ((size_t *)index->str)[1];
	docNos->store = (void **)&index->str[2 * sizeof(size_t)];

	for (size_t i = 0; i < docNos->length; i++) {
		docNos->store[i*2] = index->str + (size_t)docNos->store[i*2];
	}

	struct vector_kv *dictionary = (struct vector_kv *)(((char *)index->str) + ((size_t *)index->str)[0]);
	vector_kv_decode(dictionary);
	for (size_t i = 0; i < dictionary->length; i++) {
		dictionary->store[i*2 + 1] = (char *)index->str + (size_t)dictionary->store[i*2 + 1];
	}

	// Find average document length
	for (size_t i = 0; i < docNos->length; i++) {
		avgdl += (size_t)docNos->store[i*2 + 1];
	}
	avgdl /= docNos->length;

	// Accept input
	char term[256];
	struct vector *terms = vector_new();
	while (scanf("%s", term) == 1) {
		string_uppercase_c(term);
		vector_append(terms, strdup(term));
	}

	if (terms->length == 0) {
		exit(0);
	}

	dynamic_array<dynamic_array<std::pair<size_t, double>> *> postings;

	// Find results for strings
	for (size_t i = 0; i < terms->length; i++) {
		terms->store[i] = vector_kv_find(dictionary, (char *)terms->store[i]);
		if (terms->store[i] == NULL) {
			printf("No results\n");
			exit(0);
		} else {
			dynamic_array<std::pair<size_t, double>> *posting = posting_decompress((struct posting *)terms->store[i]);
			rank(posting, docNos, avgdl);
			postings.append(posting);
		}
	}

	dynamic_array<std::pair<size_t, double>> *result_list = intersect_postings(&postings);

	results_sort(result_list);

	for (size_t i = 0; i < result_list->length; i++) {
		size_t docId = result_list->store[i].first;
		double rsv = result_list->store[i].second;
		printf("%s %f\n", docNos->store[docId*2], rsv);
	}

	return 0;
}
