#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "memory.h"
#include "string2.h"
#include "vector_kv.h"
#include "bst_kv.h"

struct bst_kv *bst_kv_new() {
	struct bst_kv *tree = (struct bst_kv *)memory_alloc(sizeof(struct bst_kv));
	tree->root = NULL;
	tree->size = 0;

	return tree;
}

static struct bst_kv_node *make_node(char *key, void *val) {
	struct bst_kv_node *n = (struct bst_kv_node *)memory_alloc(sizeof(struct bst_kv_node));
	n->key = string_s_dup(key);
	n->val = val;
	n->link[0] = n->link[1] = NULL;
	return n;
}

void **bst_kv_insert(struct bst_kv *tree, char *key, void *val) {
	tree->size++;

	if (tree->root == NULL) {
		tree->root = make_node(key, val);
		return &tree->root->val;
	}

	struct bst_kv_node *p = tree->root;

	while (p != NULL) {
		int cmp = strcmp(&key[4], p->key);

		if (cmp < 0) {
			if (p->link[0] == NULL) {
				p->link[0] = make_node(key, val);
				return &p->link[0]->val;
			}
			p = p->link[0];
		} else if (cmp > 0) {
			if (p->link[1] == NULL) {
				p->link[1] = make_node(key, val);
				return &p->link[1]->val;
			}
			p = p->link[1];
		} else { /* |cmp == 0| */
			tree->size--;
			return &p->val;
		}
	}

	return NULL;
}

void *bst_kv_find(struct bst_kv *tree, char *key) {
	struct bst_kv_node *p = tree->root;

	while (p != NULL) {
		int cmp = strcmp(key, p->key);

		if (cmp < 0) {
			p = p->link[0];
		} else if (cmp > 0) {
			p = p->link[1];
		} else { /* |cmp == 0| */
			return p->val;
		}
	}

	return NULL;
}

static void bst_kv_to_vector_inorder(struct bst_kv_node *root, struct vector_kv *v) {
	if (root == NULL)
		return;
	bst_kv_to_vector_inorder(root->link[0], v);
	vector_kv_append(v, root->key, root->val);
	bst_kv_to_vector_inorder(root->link[1], v);
}

void bst_kv_to_vector(struct bst_kv *tree, struct vector_kv *v) {
	bst_kv_to_vector_inorder(tree->root, v);
}

/* Convert tree to sorted linked list */
/* Modeled after the DSW tree-to-vine procedure */
/* http://web.eecs.umich.edu/~qstout/pap/CACM86.pdf */
void bst_kv_linked_list(struct bst_kv *tree) {
	struct bst_kv_node pseudo_root;
	pseudo_root.link[0] = NULL;
	pseudo_root.link[1] = tree->root;

	struct bst_kv_node *tail = &pseudo_root;
	struct bst_kv_node *rest = tail->link[1];
	struct bst_kv_node *tmp;

	while (rest != NULL)
		if (rest->link[0] == NULL) {
			tail = rest;
			rest = rest->link[1];
		} else {
			tmp = rest->link[0];
			rest->link[0] = tmp->link[1];
			tmp->link[1] = rest;
			rest = tmp;
			tail->link[1] = tmp;
		}

	tree->root = pseudo_root.link[1];
}

static void bst_kv_print_inorder(struct bst_kv_node *root) {
	if (root == NULL) {
		return;
	}
	bst_kv_print_inorder(root->link[0]);
	printf("%s\n", root->key);
	bst_kv_print_inorder(root->link[1]);
}

void bst_kv_print(struct bst_kv *tree) {
	bst_kv_print_inorder(tree->root);
}

void bst_kv_print_list(struct bst_kv *tree) {
	if (tree->root == NULL) {
		return;
	}
	struct bst_kv_node *root = tree->root;
	do {
		printf("%s\n", root->key);
		root = root->link[1];
	} while (root != tree->root);
}

void bst_kv_merge_left(struct bst_kv *left_tree, struct bst_kv *right_tree) {
	struct bst_kv_node *left = left_tree->root;
	struct bst_kv_node *right = right_tree->root;

	struct bst_kv_node dummy;
	struct bst_kv_node *prev = &dummy;
	while (left != NULL && right != NULL) {
		if (strcmp(left->key, right->key) < 0) {
			prev->link[1] = left;
			left = left->link[1];
		} else {
			prev->link[1] = right;
			right = right->link[1];
		}
		prev = prev->link[1];
	}

	if (left == NULL)
		prev->link[1] = right;
	if (right == NULL)
		prev->link[1] = left;

	left_tree->root = dummy.link[1];
}
