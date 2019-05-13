#ifndef TOKENIZER_H_
#define TOKENIZER_H_

enum token_type {DOCNO, WORD, EMPTY, END};

struct tokenizer {
	struct string *str;
	size_t index;
};


struct tokenizer *tokenizer_new(struct string *str);
enum token_type tokenizer_next(struct tokenizer *tok, char *buffer);

#endif
