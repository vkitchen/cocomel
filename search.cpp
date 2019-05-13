#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "string2.h"
#include "file.h"
#include "vbyte.h"
#include "vector.h"
#include "vector_kv.h"
#include "posting.h"

struct results {
	size_t length;
	char **docNos;
	double *rsv;
};

struct vector_kv *intersect_posting(struct vector *posting) {
	struct vector_kv *out = (struct vector_kv *)posting->store[0];
	for (size_t i = 1; i < posting->length; i++) {
		out = vector_kv_intersect(out, (struct vector_kv *)posting->store[i]);
	}
	return out;
}

void results_sort(struct results *v) {
	for (size_t i = 1; i < v->length; i++) {
		char *tmp1 = v->docNos[i];
		double tmp2 = v->rsv[i];
		size_t j = i;
		while (j > 0 && tmp2 > v->rsv[j-1]) {
			v->docNos[j] = v->docNos[j-1];
			v->rsv[j] = v->rsv[j-1];
			j--;
		}
		v->docNos[j] = tmp1;
		v->rsv[j] = tmp2;
	}
}

void rank(struct vector_kv *posting, struct vector_kv *docNos, double avgdl) {
	double *weights = (double *)malloc(sizeof(double) * posting->length);

	double wt = log2((docNos->length - posting->length + 0.5) / (posting->length + 0.5));
	for (size_t i = 0; i < posting->length; i++) {
		size_t docId = (size_t)posting->store[i*2];
		size_t tf = (size_t)posting->store[i*2 + 1];
		double docLength = (size_t)docNos->store[docId*2 + 1];
		double K = 1.2 * (0.25 + 0.75 * docLength / avgdl);
		double w = wt * 2.2 * tf / (K + tf);
		weights[i] = w;
		posting->store[i*2 + 1] = &weights[i];
	}
}

int main(void) {
	double avgdl = 0;

	struct string *index = file_slurp_c("postings.dat");

	// Decode index
	struct vector_kv *docNos = (struct vector_kv *)&((size_t *)index->str)[1];
	vector_kv_decode(docNos);

	struct vector_kv *dictionary = (struct vector_kv *)(((char *)index->str) + ((size_t *)index->str)[0]);
	vector_kv_decode(dictionary);
	for (size_t i = 0; i < dictionary->length; i++) {
		dictionary->store[i*2 + 1] = (char *)index->str + (size_t)dictionary->store[i*2 + 1];
		posting_decode((struct posting *)dictionary->store[i*2 + 1]);
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

	// Find results for strings
	for (size_t i = 0; i < terms->length; i++) {
		terms->store[i] = vector_kv_find(dictionary, (char *)terms->store[i]);
		if (terms->store[i] == NULL) {
			printf("No results\n");
			exit(0);
		} else { 
			terms->store[i] = posting_decompress((struct posting *)terms->store[i]);
			rank((struct vector_kv *)terms->store[i], docNos, avgdl);
		}
	}

	struct vector_kv *result_list = intersect_posting(terms);
	struct results *results = (struct results *)malloc(sizeof(struct results));
	results->length = result_list->length;
	results->docNos = (char **)malloc(result_list->length * sizeof(char *));
	results->rsv = (double *)malloc(result_list->length * sizeof(double));

	// Add relevancy to results and sort

	for (size_t i = 0; i < result_list->length; i++) {
		size_t docI = (size_t)result_list->store[i*2];	
		char *docNo = (char *)docNos->store[docI * 2];
		double weight = *(double *)result_list->store[i*2 + 1];
		results->docNos[i] = docNo;
		results->rsv[i] = weight;
	}

	results_sort(results);

	// Print results
	for (size_t i = 0; i < results->length; i++) {
		printf("%s %f\n", results->docNos[i], results->rsv[i]);
	}
	
	return 0;
}
