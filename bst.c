#include "str.h"
#include "memory.h"
#include "posting.h"

#include "bst.h"

void bst_init(struct bst *b, struct str key, uint32_t val)
	{
	b->left = b->right = NULL;
	b->key = str_dup_c(key);
	posting_init(&b->store);
	posting_append(&b->store, val);
	}
		
void bst_insert(struct bst *b, struct str key, uint32_t val, uint32_t *length)
	{
	for (;;)
		{
		int cmp = string_cmp(str_c(key), b->key);

		if (cmp < 0)
			{
			if (b->left == NULL)
				{
				b->left = memory_alloc(sizeof(struct bst));
				bst_init(b->left, key, val);
				(*length)++;
				return;
				}
			b = b->left;
			}
		else if (cmp > 0)
			{
			if (b->right == NULL)
				{
				b->right = memory_alloc(sizeof(struct bst));
				bst_init(b->right, key, val);
				(*length)++;
				return;
				}
			b = b->right;
			}
		else /* |cmp == 0| */
			{
			posting_append(&b->store, val);
			return;
			}
		}
	}

/*
		char *write(char *start, char *ptr_buffer, char *val_buffer)
			{
			bst *tree = this;
			while (tree != NULL)
				{
				if (tree->left == NULL)
					{
					((uint32_t *)ptr_buffer)[0] = val_buffer - start;
					ptr_buffer += sizeof(uint32_t);
					val_buffer += string_copy(val_buffer, tree->key);

					((uint32_t *)ptr_buffer)[0] = val_buffer - start;
					ptr_buffer += sizeof(uint32_t);
					val_buffer += tree->store.write(val_buffer);

					tree = tree->right;
					}
				else
					{
					bst *temp = tree->left;
					tree->left = temp->right;
					temp->right = tree;
					tree = temp;
					}
				}

			return val_buffer;
			}
	};
*/

