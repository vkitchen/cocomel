#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
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

	char tok_buffer[260];
	struct string *file = file_slurp_c(argv[1]);
	struct tokenizer *tok = tokenizer_new(file);
	enum token_type token;
	struct postings *postings = postings_new();
	do {
		token = tokenizer_next(tok, tok_buffer);
		if (token == DOCNO) {
			postings_new_doc(postings, string_s_dup(tok_buffer));
		} else if (token != END && token != EMPTY) {
			postings_append(postings, tok_buffer);
		}
	} while (token != END);

	postings_write(postings, file, "index.dat");

	return 0;
}
