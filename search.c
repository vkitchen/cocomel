#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
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

void uppercase(char *str) {
	while ((*str = toupper(*str))) {
		++str;
	}
}

struct vector_kv *decompress_posting(struct posting *posting) {
	struct vector_kv *out = vector_kv_new();
	size_t prevI = 0;
	size_t docI = 0;
	size_t di = 0;
	size_t ci = 0;
	while (ci < posting->count_length && di < posting->id_length) {
		di += vbyte_read(&posting->id_store[di], &docI);
		docI += prevI;
		prevI = docI;
		size_t count = posting->count_store[ci];
		vector_kv_append(out, (void *)docI, (void *)count);
		ci++;
	}
	return out;
}

struct vector_kv *vector_kv_intersect(struct vector_kv *a, struct vector_kv *b) {
	struct vector_kv *out = vector_kv_new();
	for (;;) {
		if (a->length == 0 || b->length == 0) {
			goto done;
		}
		if (a->store[0] == b->store[0]) {
			vector_kv_append(out, a->store[0], (void *)((size_t)a->store[1] + (size_t)b->store[1]));
			a->length--;
			a->store += 2;
			b->length--;
			b->store += 2;
			continue;
		}
		while (a->length > 0 && b->length > 0 && a->store[0] < b->store[0]) {
			a->length--;
			a->store += 2;
		}
		while (a->length > 0 && b->length > 0 && b->store[0] < a->store[0]) {
			b->length--;
			b->store += 2;
		}
	}
	done: return out;
}

struct vector_kv *intersect_posting(struct vector *posting) {
	struct vector_kv *out = posting->store[0];
	for (size_t i = 1; i < posting->length; i++) {
		out = vector_kv_intersect(out, posting->store[i]);
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

int main(void) {
	struct string *posting = file_slurp_c("postings.dat");
	((size_t *)posting->str)[0] += (size_t)posting->str;
	((size_t *)posting->str)[1] += (size_t)posting->str;

	// Decode doc no.s
	struct vector_kv *docNos = ((struct vector_kv **)posting->str)[0];
	docNos->store = (void **)((char *)docNos->store + (size_t)posting->str);
	for (size_t i = 0; i < docNos->length; i++) {
		docNos->store[i * 2] = (void *)((char *)docNos->store[i * 2] + (size_t)posting->str);
	}

	// Decode dictionary
	struct vector_kv *dictionary = ((struct vector_kv **)posting->str)[1];
	dictionary->store = (void **)((char *)dictionary->store + (size_t)posting->str);
	for (size_t i = 0; i < dictionary->length; i++) {
		dictionary->store[i * 2] = (void *)((char *)dictionary->store[i * 2] + (size_t)posting->str);
		dictionary->store[i*2 + 1] = (void *)((char *)dictionary->store[i*2 + 1] + (size_t)posting->str);
		struct posting *post = dictionary->store[i*2 + 1];
		post->count_store = (void *)((char *)post->count_store + (size_t)posting->str);
		post->id_store = (void *)((char *)post->id_store + (size_t)posting->str);
	}

	// Accept input
	char term[256];
	struct vector *terms = vector_new();
	while (scanf("%s", term) == 1) {
		uppercase(term);
		vector_append(terms, strdup(term));
	}

	if (terms->length == 0) {
		exit(0);
	}

	// Find results for strings
	for (size_t i = 0; i < terms->length; i++) {
		terms->store[i] = vector_kv_find(dictionary, terms->store[i]);
		if (terms->store[i] == NULL) {
			printf("No results\n");
			exit(0);
		} else { 
			terms->store[i] = decompress_posting(terms->store[i]);
		}
	}

	struct vector_kv *result_list = intersect_posting(terms);
	struct results *results = malloc(sizeof(struct results));
	results->length = result_list->length;
	results->docNos = malloc(result_list->length * sizeof(char *));
	results->rsv = malloc(result_list->length * sizeof(double));

	// Add relevancy to results and sort

	for (size_t i = 0; i < result_list->length; i++) {
		size_t docI = (size_t)result_list->store[i*2];	
		char *docNo = (char *)docNos->store[docI * 2];
		double freq = (double)(size_t)result_list->store[i*2+1];
		double docLength = (double)(size_t)docNos->store[docI*2+1];
		results->docNos[i] = docNo;
		results->rsv[i] = freq / docLength;
	}

	results_sort(results);

	// Print results
	for (size_t i = 0; i < results->length; i++) {
		printf("%s %f\n", results->docNos[i], results->rsv[i]);
	}
	
	return 0;
}
