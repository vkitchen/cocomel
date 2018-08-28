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
