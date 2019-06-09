#pragma once

#include "str.h"
#include "memory.h"

template <typename TBacking, typename T>
class bst
	{
	private:
		char *key;
		bst *left;
		bst *right;
		TBacking store;

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		bst(str key, T val)
			{
			this->key = key.c_dup();
			store.append(val);
			left = right = NULL;
			}
		
		void insert(str key, T val, uint32_t *length)
			{
			bst *tree = this;

			for (;;)
				{
				int cmp = strcmp(key.c_str(), tree->key);

				if (cmp < 0)
					{
					if (tree->left == NULL)
						{
						tree->left = new bst(key, val);
						(*length)++;
						return;
						}
					tree = tree->left;
					}
				else if (cmp > 0)
					{
					if (tree->right == NULL)
						{
						tree->right = new bst(key, val);
						(*length)++;
						return;
						}
					tree = tree->right;
					}
				else /* |cmp == 0| */
					{
					tree->store.append(val);
					return;
					}
				}
			}

		void write(char *start, char **ptr_buffer, char **val_buffer)
			{
			if (left != NULL)
				left->write(start, ptr_buffer, val_buffer);

			((uint32_t *)*ptr_buffer)[0] = *val_buffer - start;
			*ptr_buffer += sizeof(uint32_t);
			*val_buffer += string_copy(*val_buffer, key);

			((uint32_t *)*ptr_buffer)[0] = *val_buffer - start;
			*ptr_buffer += sizeof(uint32_t);
			*val_buffer += store.write(*val_buffer);

			if (right != NULL)
				right->write(start, ptr_buffer, val_buffer);
			}
	};
