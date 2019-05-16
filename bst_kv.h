#ifndef BST_KV_H_
#define BST_KV_H_


struct bst_kv_node {
	struct bst_kv_node *link[2];
	char *key;
	void *val;
};

struct bst_kv {
	struct bst_kv_node *root;
	size_t size;
};

struct bst_kv *bst_kv_new();
void **bst_kv_insert(struct bst_kv *tree, char *key, void *val);
void *bst_kv_find(struct bst_kv *tree, char *key);
void bst_kv_linked_list(struct bst_kv *tree);
void bst_kv_to_vector(struct bst_kv *tree, struct vector_kv *v);
void bst_kv_print(struct bst_kv *tree);
void bst_kv_print_list(struct bst_kv *tree);
void bst_kv_merge_left(struct bst_kv *left_tree, struct bst_kv *right_tree);

#endif
