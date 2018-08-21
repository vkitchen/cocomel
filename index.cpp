#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "stdlib2/string2.h"
#include "stdlib2/file.h"
#include "stdlib2/memory.h"
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <map>

enum token_type {DOCNO, WORD, END};
struct token {
	char *value;
	enum token_type type;
};

struct tokenizer {
	struct string *str;
	size_t index;
};

struct tokenizer *tokenizer_new(struct string *str) {
	struct tokenizer *tok = (struct tokenizer *)memory_alloc(sizeof(struct tokenizer));
	tok->str = str;
	tok->index = 0;
	return tok;
}

int prefix(const char *pre, const char *str)
{
	return strncmp(pre, str, strlen(pre)) == 0;
}

void tokenizer_advance(struct tokenizer *tok) {
	// Whitespace
	while(tok->index < tok->str->bytes && isspace(tok->str->str[tok->index])) {
		tok->index++;
	}

	// Ignored tags
	while (tok->index < tok->str->bytes && tok->str->str[tok->index] == '<' && !prefix("<DOCNO>", &tok->str->str[tok->index])) {
		char *found = strstr(&tok->str->str[tok->index], ">");
		if (found == NULL) {
			fprintf(stderr, "ERROR: Tokenizer encountered unmatched <");
		}
		tok->index += found - &tok->str->str[tok->index] + 1; // jump over the closing arrow bracket

		while(tok->index < tok->str->bytes && isspace(tok->str->str[tok->index])) {
			tok->index++;
		}
	}
}

struct token tokenizer_next(struct tokenizer *tok) {
	struct token token;
	char word[256];

	tokenizer_advance(tok);

	if (prefix("<DOCNO>", &tok->str->str[tok->index])) {
		tok->index += sizeof("<DOCNO>");

		tokenizer_advance(tok);

		int i = 0;
		while (i < 256 && i + tok->index < tok->str->bytes && !isspace(tok->str->str[tok->index + i])) {
			word[i] = tok->str->str[tok->index + i];
			i++;
		}
		word[i] = '\0';
		token.type = DOCNO;
		token.value = strdup(word);

		tok->index += i;
		tokenizer_advance(tok);

		return token;
	}

	if (tok->index < tok->str->bytes) {
		int i = 0;
		int j = 0;
		while (j < 256 && i + tok->index < tok->str->bytes && !isspace(tok->str->str[tok->index + i]) && tok->str->str[tok->index + i] != '<') {
			char c = tok->str->str[tok->index + i];
			if (90 < c) {
				c -= 'a' - 'A';
			}
			if (c < 48 || (57 < c && c < 65) || 90 < c) {
				i++;
				continue;
			}
			word[j] = tok->str->str[tok->index + i];
			i++;
			j++;
		}
		word[j] = '\0';
		token.type = WORD;
		token.value = strdup(word);

		tok->index += i;
		tokenizer_advance(tok);

		return token;
	}

	token.type = END;
	return token;
}

int main(void) {
	struct string *file = file_slurp_c("wsj.xml");
	struct tokenizer *tok = tokenizer_new(file);
	std::vector<std::string> docNos;
	std::map<std::string, std::vector<size_t>> postings;
	struct token token;
	size_t docI = -1;
	do {
		token = tokenizer_next(tok);
		if (token.type == DOCNO) {
			docI++;
			std::string str(token.value);
			docNos.push_back(str);
		} else if (token.type != END) {
			std::string word(token.value);
			if (postings.count(word) > 0) {
				if (postings[word].back() != docI) {
					postings[word].push_back(docI);
				}
			} else {
				std::vector<size_t> docs;
				postings[word] = docs;
				postings[word].push_back(docI);
			}
		}
	} while (token.type != END);

	exit(0);

	std::ofstream fh;
	fh.open("postings.dat", std::ios::binary);
	size_t docCount = docNos.size();
	fh.write((char *)&docCount, 8);
	for (auto &docNo : docNos) {
		size_t docNoSize = docNo.size();
		fh.write((char *)&docNoSize, 8);
		fh.write(&docNo[0], docNoSize);
	}
	size_t postingsLength = postings.size();
	fh.write((char *)&postingsLength, 8);
	for (auto &post : postings) {
		size_t stringLength = post.first.size();
		fh.write((char *)&stringLength, 8);
		fh.write(&post.first[0], stringLength);
		size_t listLength = post.second.size();
		fh.write((char *)&listLength, 8);
		for (auto &list : post.second) {
			fh.write((char *)&list, 8);
		}
	}
	fh.close();

	return 0;
}
