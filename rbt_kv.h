#ifndef RBT_KV_H_
#define RBT_KV_H_

/* Based off of libavl (just insert) */

#define RBT_KV_MAX_HEIGHT 48

enum rbt_kv_color {
	RBT_KV_BLACK,
	RBT_KV_RED
};

struct rbt_kv_node {
	struct rbt_kv_node *link[2];
	char color;
	char *key;
	void *val;
};

struct rbt_kv {
	struct rbt_kv_node *root;
	size_t size;
};

struct rbt_kv *rbt_kv_new();
void **rbt_kv_insert(struct rbt_kv *tree, char *key, void *val);
void *rbt_kv_find(struct rbt_kv *tree, char *key);
void rbt_kv_linked_list(struct rbt_kv *tree);
void rbt_kv_print(struct rbt_kv *tree);
void rbt_kv_print_list(struct rbt_kv *tree);
void rbt_kv_merge_left(struct rbt_kv *left_tree, struct rbt_kv *right_tree);

#endif
