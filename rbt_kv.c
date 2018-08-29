#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "memory.h"
#include "rbt_kv.h"

static int is_red(struct rbt_kv_node *root) {
	return root != NULL && root->red;
}

static struct rbt_kv_node *rbt_kv_single(struct rbt_kv_node *root, int dir) {
	if (root == NULL) {
		return NULL;
	}

	struct rbt_kv_node *save = root->link[!dir];

	root->link[!dir] = save->link[dir];
	save->link[dir] = root;

	root->red = 1;
	save->red = 0;

	return save;
}

static struct rbt_kv_node *rbt_kv_double(struct rbt_kv_node *root, int dir) {
	if (root == NULL) {
		return NULL;
	}

	root->link[!dir] = rbt_kv_single(root->link[!dir], !dir);

	return rbt_kv_single(root, dir);
}

static struct rbt_kv_node *make_node(char *key, void *val) {
	struct rbt_kv_node *node = malloc(sizeof(struct rbt_kv_node));

	node->key = key;
	node->val = val;
	node->red = 1;
	node->link[0] = NULL;
	node->link[1] = NULL;

	return node;
}

struct rbt_kv *rbt_kv_new() {
	struct rbt_kv *tree = malloc(sizeof(struct rbt_kv));
	tree->root = NULL;
	return tree;
}

/* TODO consider returning pointer to node */
void rbt_kv_insert(struct rbt_kv *tree, char *key, void *val) {
	if (tree->root == NULL) {
		tree->root = make_node(key, val);
	} else {
		struct rbt_kv_node head = { 0 }; /* False tree root */

		struct rbt_kv_node *g, *t; /* Grandparent & parent */
		struct rbt_kv_node *p, *q; /* Iterator & parent */
		int dir = 0, last = 0;

		/* Set up helpers */
		t = &head;
		g = p = NULL;
		q = t->link[1] = tree->root;

		/* Search down the tree */
		for (;;) {
			if (q == NULL) {
				p->link[dir] = q = make_node(key, val);
			} else if (is_red(q->link[0]) && is_red(q->link[1])) {
				/* Color flip */
				q->red = 1;
				q->link[0]->red = 0;
				q->link[1]->red = 1;
			}

			/* Fix red violation */
			if (is_red(q) && is_red(p)) {
				int dir2 = t->link[1] == g;
				if (q == p->link[last]) {
					t->link[dir2] = rbt_kv_single(g, !last);
				} else {
					t->link[dir2] = rbt_kv_double(g, !last);
				}
			}

			/* Stop if found */
			last = dir;
			dir = strcmp(q->key, key) < 0;
			if (dir == 0) {
				break;
			}

			/* Update helpers */
			if (g != NULL) {
				t = g;
			}

			g = p, p = q;
			q = q->link[dir];
		}

		/* Update root */
		tree->root = head.link[1];
	}

	/* Make root black */
	tree->root->red = 0;
}

struct rbt_kv *rbt_kv_find(struct rbt_kv *tree, char *key) {
	struct rbt_kv_node *it = tree->root;

	while (it != NULL) {
		int dir = strcmp(it->key, key) < 0;
		if (dir == 0) {
			return it->val;
		} else {
			it = it->link[dir];
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
