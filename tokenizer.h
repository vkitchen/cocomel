#ifndef TOKENIZER_H_
#define TOKENIZER_H_

enum token_type {DOCNO, WORD, END};
struct token {
	char *value;
	enum token_type type;
};

struct tokenizer {
	struct string *str;
	size_t index;
};


struct tokenizer *tokenizer_new(struct string *str);
struct token tokenizer_next(struct tokenizer *tok);

#endif
