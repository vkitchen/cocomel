/* Produced by texiweb from libavl.w. */

/* libavl - library for manipulation of binary trees.
	 Copyright (C) 1998-2002, 2004 Free Software Foundation, Inc.

	 This program is free software; you can redistribute it and/or
	 modify it under the terms of the GNU General Public License as
	 published by the Free Software Foundation; either version 2 of the
	 License, or (at your option) any later version.

	 This program is distributed in the hope that it will be useful, but
	 WITHOUT ANY WARRANTY; without even the implied warranty of
	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
	 See the GNU General Public License for more details.

	 You should have received a copy of the GNU General Public License
	 along with this program; if not, write to the Free Software
	 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
	 02111-1307, USA.

	 The author may be contacted at <blp@gnu.org> on the Internet, or
	 write to Ben Pfaff, Stanford University, Computer Science Dept., 353
	 Serra Mall, Stanford CA 94305, USA.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "memory.h"
#include "rbt_kv.h"

struct rbt_kv *rbt_kv_new() {
	struct rbt_kv *tree = memory_alloc(sizeof(struct rbt_kv));
	tree->root = NULL;
	tree->size = 0;

	return tree;
}

/* TODO rewrite this. It is the only code in this file I didn't write. It is stopping this project from being MIT */
/* TODO appears to have a memory leak */
void **rbt_kv_insert(struct rbt_kv *tree, char *key, void *val) {
	struct rbt_kv_node *pa[RBT_KV_MAX_HEIGHT]; /* Nodes on stack. */
	unsigned char da[RBT_KV_MAX_HEIGHT];	 /* Directions moved from stack nodes. */
	int k;														 /* Stack height. */

	struct rbt_kv_node *p; /* Traverses tree looking for insertion point. */
	struct rbt_kv_node *n; /* Newly inserted node. */

	pa[0] = (struct rbt_kv_node *)&tree->root; // TODO seems dodgy
	da[0] = 0;
	k = 1;
	for (p = tree->root; p != NULL; p = p->link[da[k - 1]]) {
		int cmp = strcmp(key, p->key);
		if (cmp == 0) {
			return &p->val;
		}

		pa[k] = p;
		da[k++] = cmp > 0;
	}

	n = pa[k - 1]->link[da[k - 1]] = memory_alloc(sizeof(struct rbt_kv_node));
	n->key = key;
	n->val = val;
	n->link[0] = n->link[1] = NULL;
	n->color = RBT_KV_RED;
	tree->size++;

	while (k >= 3 && pa[k - 1]->color == RBT_KV_RED) {
		if (da[k - 2] == 0) {
			struct rbt_kv_node *y = pa[k - 2]->link[1];
			if (y != NULL && y->color == RBT_KV_RED) {
				pa[k - 1]->color = y->color = RBT_KV_BLACK;
				pa[k - 2]->color = RBT_KV_RED;
				k -= 2;
			} else {
				struct rbt_kv_node *x;

				if (da[k - 1] == 0) {
					y = pa[k - 1];
				} else {
					x = pa[k - 1];
					y = x->link[1];
					x->link[1] = y->link[0];
					y->link[0] = x;
					pa[k - 2]->link[0] = y;
				}

				x = pa[k - 2];
				x->color = RBT_KV_RED;
				y->color = RBT_KV_BLACK;

				x->link[0] = y->link[1];
				y->link[1] = x;
				pa[k - 3]->link[da[k - 3]] = y;
				break;
			}
		} else {
			struct rbt_kv_node *y = pa[k - 2]->link[0];
			if (y != NULL && y->color == RBT_KV_RED) {
				pa[k - 1]->color = y->color = RBT_KV_BLACK;
				pa[k - 2]->color = RBT_KV_RED;
				k -= 2;
			} else {
				struct rbt_kv_node *x;

				if (da[k - 1] == 1) {
					y = pa[k - 1];
				} else {
					x = pa[k - 1];
					y = x->link[0];
					x->link[0] = y->link[1];
					y->link[1] = x;
					pa[k - 2]->link[1] = y;
				}

				x = pa[k - 2];
				x->color = RBT_KV_RED;
				y->color = RBT_KV_BLACK;

				x->link[1] = y->link[0];
				y->link[0] = x;
				pa[k - 3]->link[da[k - 3]] = y;
				break;
			}
		}
	}
	if (tree->root != NULL) {
		tree->root->color = RBT_KV_BLACK;
	}

	return &n->val;
}

void *rbt_kv_find(struct rbt_kv *tree, char *key) {
	struct rbt_kv_node *p = tree->root;

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

static struct rbt_kv_node *list_append(struct rbt_kv_node *left, struct rbt_kv_node *right) {
	if (left == NULL) {
		return right;
	}
	if (right == NULL) {
		return left;
	}

	struct rbt_kv_node *tail = right->link[0];

	left->link[0]->link[1] = right; /* Old left tail to old right head */
	right->link[0]->link[1] = left; /* Right tail to left head */

	right->link[0] = left->link[0]; /* Old right head to old left tail */
	left->link[0] = tail; /* Left head to right tail */

	return left;
}

static struct rbt_kv_node *rbt_kv_linked_list_join(struct rbt_kv_node *root) {
	struct rbt_kv_node *left, *right;

	if (root == NULL) {
		return NULL;
	}

	left = rbt_kv_linked_list_join(root->link[0]);
	right = rbt_kv_linked_list_join(root->link[1]);

	root->link[0] = root;
	root->link[1] = root;

	left = list_append(left, root);
	left = list_append(left, right);

	return left;
}

/* Convert tree to doubly linked list */
void rbt_kv_linked_list(struct rbt_kv *tree) {
	tree->root = rbt_kv_linked_list_join(tree->root);
}

static void rbt_kv_print_inorder(struct rbt_kv_node *root) {
	if (root == NULL) {
		return;
	}
	rbt_kv_print_inorder(root->link[0]);
	printf("%s\n", root->key);
	rbt_kv_print_inorder(root->link[1]);
}

void rbt_kv_print(struct rbt_kv *tree) {
	rbt_kv_print_inorder(tree->root);
}

void rbt_kv_print_list(struct rbt_kv *tree) {
	if (tree->root == NULL) {
		return;
	}
	struct rbt_kv_node *root = tree->root;
	do {
		printf("%s\n", root->key);
		root = root->link[1];
	} while (root != tree->root);
}

// static void list_insert_after(struct rbt_kv_node *list, struct rbt_kv_node *node) {
// 	node->link[0] = list;
// 	node->link[1] = list->link[1];
// 	list->link[1]->link[0] = node;
// 	list->link[1] = node;
// }

static void list_insert_before(struct rbt_kv_node *list, struct rbt_kv_node *node) {
	node->link[0] = list->link[0];
	node->link[1] = list;
	list->link[0]->link[1] = node;
	list->link[0] = node;
}

void rbt_kv_merge_left(struct rbt_kv *left_tree, struct rbt_kv *right_tree) {
	struct rbt_kv_node *left = left_tree->root;
	struct rbt_kv_node *right = right_tree->root;
	struct rbt_kv_node *tmp;
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
