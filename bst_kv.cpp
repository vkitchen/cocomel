#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "memory.h"
#include "bst_kv.h"

struct bst_kv *bst_kv_new() {
	struct bst_kv *tree = (struct bst_kv *)memory_alloc(sizeof(struct bst_kv));
	tree->root = NULL;
	tree->size = 0;

	return tree;
}

static struct bst_kv_node *make_node(char *key, void *val) {
	struct bst_kv_node *n = (struct bst_kv_node *)memory_alloc(sizeof(struct bst_kv_node));
	n->key = key;
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
		int cmp = strcmp(key, p->key);

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

static struct bst_kv_node *list_append(struct bst_kv_node *left, struct bst_kv_node *right) {
	if (left == NULL) {
		return right;
	}
	if (right == NULL) {
		return left;
	}

	struct bst_kv_node *tail = right->link[0];

	left->link[0]->link[1] = right; /* Old left tail to old right head */
	right->link[0]->link[1] = left; /* Right tail to left head */

	right->link[0] = left->link[0]; /* Old right head to old left tail */
	left->link[0] = tail; /* Left head to right tail */

	return left;
}

static struct bst_kv_node *bst_kv_linked_list_join(struct bst_kv_node *root) {
	struct bst_kv_node *left, *right;

	if (root == NULL) {
		return NULL;
	}

	left = bst_kv_linked_list_join(root->link[0]);
	right = bst_kv_linked_list_join(root->link[1]);

	root->link[0] = root;
	root->link[1] = root;

	left = list_append(left, root);
	left = list_append(left, right);

	return left;
}

/* Convert tree to doubly linked list */
void bst_kv_linked_list(struct bst_kv *tree) {
	tree->root = bst_kv_linked_list_join(tree->root);
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

// static void list_insert_after(struct bst_kv_node *list, struct bst_kv_node *node) {
// 	node->link[0] = list;
// 	node->link[1] = list->link[1];
// 	list->link[1]->link[0] = node;
// 	list->link[1] = node;
// }

static void list_insert_before(struct bst_kv_node *list, struct bst_kv_node *node) {
	node->link[0] = list->link[0];
	node->link[1] = list;
	list->link[0]->link[1] = node;
	list->link[0] = node;
}

void bst_kv_merge_left(struct bst_kv *left_tree, struct bst_kv *right_tree) {
	struct bst_kv_node *left = left_tree->root;
	struct bst_kv_node *right = right_tree->root;
	struct bst_kv_node *tmp;
	int moved = 0;
	do {
		while (strcmp(left->key, right->key) < 0 && (left != left_tree->root || !moved)) {
			left = left->link[1];
			moved = 1;
		}
		tmp = right;
		right = right->link[1];
		list_insert_before(left, tmp);
		if (left_tree->root == left && !moved) {
			left_tree->root = tmp;
		}
	} while (right != right_tree->root);
}
