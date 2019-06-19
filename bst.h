#pragma once

#include "str.h"
#include "memory.h"

template <typename TBacking, typename T>
class bst
	{
	private:
		char *key;
		bst *left = NULL;
		bst *right = NULL;
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
			}
		
		void insert(str key, T val, uint32_t *length)
			{
			bst *tree = this;

			for (;;)
				{
				int cmp = string_cmp(key.c_str(), tree->key);

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
