#pragma once

#include "memory.h"

class bst
	{
	private:
		char *key;
		bst *left;
		bst *right;

	public:
		void *val;

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		bst(char *key, void *val);
		
		void **insert(char *key, void *val, uint32_t *length);

		void *find(char *key);

		void write(char **ptr_buffer, char **val_buffer);
	};
