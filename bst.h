#ifndef BST_H
#define BST_H

#include "posting.h"
#include "str.h"

struct bst
	{
	char *key;
	struct bst *left;
	struct bst *right;
	struct posting store;
	};

void bst_init(struct bst *b, struct str key, uint32_t val);
void bst_insert(struct bst *b, struct str key, uint32_t val, uint32_t *length);
char *bst_write(struct bst *b, char *start, char *ptr_buffer, char *val_buffer);

#endif

