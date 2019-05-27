#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "memory.h"
#include "string2.h"
#include "vector_kv.h"
#include "posting.h"
#include "bst_kv.h"

static inline struct bst_kv *make_node(char *key, void *val) {
	struct bst_kv *n = (struct bst_kv *)memory_alloc(sizeof(struct bst_kv));
	n->key = string_s_dup(key);
	n->val = val;
	n->left = n->right = NULL;
	return n;
}

struct bst_kv *bst_kv_new(char *key, void *val) {
	return make_node(key, val);
}


void **bst_kv_insert(struct bst_kv *tree, char *key, void *val, uint32_t *length) {
	while (tree != NULL) {
		int cmp = strcmp(&key[4], tree->key);

		if (cmp < 0) {
			if (tree->left == NULL) {
				tree->left = make_node(key, val);
				(*length)++;
				return &tree->left->val;
			}
			tree = tree->left;
		} else if (cmp > 0) {
			if (tree->right == NULL) {
				tree->right = make_node(key, val);
				(*length)++;
				return &tree->right->val;
			}
			tree = tree->right;
		} else { /* |cmp == 0| */
			return &tree->val;
		}
	}

	return NULL;
}

void *bst_kv_find(struct bst_kv *tree, char *key) {
	while (tree != NULL) {
		int cmp = strcmp(key, tree->key);

		if (cmp < 0) {
			tree = tree->left;
		} else if (cmp > 0) {
			tree = tree->right;
		} else { /* |cmp == 0| */
			return tree->val;
		}
	}

	return NULL;
}

void bst_kv_write(struct bst_kv *tree, char **ptr_buffer, char **val_buffer) {
	if (tree == NULL)
		return;

	bst_kv_write(tree->left, ptr_buffer, val_buffer);

	((size_t *)*ptr_buffer)[0] = *val_buffer - *ptr_buffer;
	*ptr_buffer += sizeof(size_t);
	size_t delta = string_copy_c(*val_buffer, tree->key);
	*val_buffer += delta;

	((size_t *)*ptr_buffer)[0] = *val_buffer - *ptr_buffer;
	*ptr_buffer += sizeof(size_t);
	delta = posting_write((struct posting *)tree->val, *val_buffer);
	*val_buffer += delta;

	bst_kv_write(tree->right, ptr_buffer, val_buffer);
}

void bst_kv_to_vector(struct bst_kv *tree, struct vector_kv *v) {
	if (tree == NULL)
		return;
	bst_kv_to_vector(tree->left, v);
	vector_kv_append(v, tree->key, tree->val);
	bst_kv_to_vector(tree->right, v);
}
