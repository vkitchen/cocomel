/*
	FUCS.H
	------
	Copyright (c) 2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef FUCS_H
#define FUCS_H

#include "str.h"

enum token_type {DOCNO, WORD, END};

void fucs_init();
struct tokenizer *fucs_parser_new(char *document);
enum token_type fucs_parser_next(struct tokenizer *t, struct str buffer);
void fucs_print();

#endif
