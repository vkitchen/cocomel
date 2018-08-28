#ifndef RBT_KV_H_
#define RBT_KV_H_

/* Based off of http://www.eternallyconfuzzled.com/tuts/datastructures/jsw_tut_rbtree.aspx */

struct rbt_kv_node {
	char *key;
	void *val;
	int red;
	struct rbt_kv_node *link[2];
};

struct rbt_kv {
	struct rbt_kv_node *root;
};

struct rbt_kv *rbt_kv_new();
void rbt_kv_insert(struct rbt_kv *tree, char *key, void *val);
struct rbt_kv *rbt_kv_find(struct rbt_kv *tree, char *key);

#endif
