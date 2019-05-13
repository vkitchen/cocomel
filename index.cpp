#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "tokenizer.h"
#include "string2.h"
#include "file.h"
#include "postings.h"

const char *usage = "\
Usage: index [file]\
";

int main(int argc, char **argv) {
	if (argc != 2) {
		puts(usage);
		return 1;
	}

	struct string *file = file_slurp_c(argv[1]);
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

	postings_write(postings, file, "index.dat");

	return 0;
}
