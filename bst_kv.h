#ifndef BST_KV_H_
#define BST_KV_H_


struct bst_kv {
	char *key;
	void *val;
	struct bst_kv *left;
	struct bst_kv *right;
};

struct bst_kv *bst_kv_new(char *key, void *val);
void **bst_kv_insert(struct bst_kv *tree, char *key, void *val, uint32_t *length);
void *bst_kv_find(struct bst_kv *tree, char *key);
void bst_kv_write(struct bst_kv *tree, char **ptr_buffer, char **val_buffer);
void bst_kv_to_vector(struct bst_kv *tree, struct vector_kv *v);

#endif
