#ifndef HASH_TABLE_H
#define HASH_TABLE_H

#include "bst.h"
#include "str.h"

#define HTCAP (1 << 16)

struct hash_table
	{
	struct bst *store[HTCAP];
	uint32_t lengths[HTCAP];
	};

void hash_table_init(struct hash_table *h);
void hash_table_insert(struct hash_table *h, struct str key, uint32_t val);
struct posting *hash_table_find(struct hash_table *h, char *key);
uint32_t hash_table_write(struct hash_table *h, char *buffer);
struct hash_table *hash_table_read(struct hash_table *h, char *buffer);

#endif

