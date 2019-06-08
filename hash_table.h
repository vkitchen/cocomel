#pragma once

#include "bst.h"

class hash_table
	{
	private:
		size_t capacity;
		bst **store;
		uint32_t *lengths;

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		hash_table();

		void **insert(char *key, void *val);

		void *find(char *key);

		size_t write(char *buffer);

		static hash_table *read(char *buffer);
	};
