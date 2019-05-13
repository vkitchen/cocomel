#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "tokenizer.h"
#include "string2.h"
#include "file.h"
#include "postings.h"

int main(void) {
	struct string *file = file_slurp_c("document.xml");
	struct tokenizer *tok = tokenizer_new(file);
	struct token token;
	struct postings *postings = postings_new();
	do {
		token = tokenizer_next(tok);
		if (token.type == DOCNO) {
			postings_new_doc(postings, token.value);
		} else if (token.type != END && token.value != NULL) {
			postings_append(postings, token.value);
		}
	} while (token.type != END);

	postings_write(postings, file, "postings.dat");

	return 0;
}
