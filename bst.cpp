#include <cstring>
#include "string2.h"
#include "posting.h"
#include "bst.h"

bst::bst(char *key, void *val) {
	this->key = string_s_dup(key);
	this->val = val;
	left = right = NULL;
}

void **bst::insert(char *key, void *val, uint32_t *length) {
	bst *tree = this;

	for (;;) {
		int cmp = strcmp(&key[4], tree->key);

		if (cmp < 0) {
			if (tree->left == NULL) {
				tree->left = new bst(key, val);
				(*length)++;
				return &tree->left->val;
			}
			tree = tree->left;
		} else if (cmp > 0) {
			if (tree->right == NULL) {
				tree->right = new bst(key, val);
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

void *bst::find(char *key) {
	bst *tree = this;

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

void bst::write(char **ptr_buffer, char **val_buffer) {
	if (left != NULL)
		left->write(ptr_buffer, val_buffer);

	((size_t *)*ptr_buffer)[0] = *val_buffer - *ptr_buffer;
	*ptr_buffer += sizeof(size_t);
	size_t delta = string_copy_c(*val_buffer, key);
	*val_buffer += delta;

	((size_t *)*ptr_buffer)[0] = *val_buffer - *ptr_buffer;
	*ptr_buffer += sizeof(size_t);
	delta = ((posting *)val)->write(*val_buffer);
	*val_buffer += delta;

	if (right != NULL)
		right->write(ptr_buffer, val_buffer);
}
