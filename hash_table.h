#pragma once

#include "bst.h"

template <typename TBacking, typename T>
class hash_table
	{
	private:
		size_t capacity;
		bst<TBacking, T> **store;
		uint32_t *lengths;

	private:
		static inline unsigned int hash(char *key)
			{
			unsigned int result = 0;
			
			while (*key != '\0')
				result = (*key++ + 31 * result);

			return result;
			}

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		hash_table()
			{
			capacity = 1 << 16;
			store = (bst<TBacking, T> **)memory_alloc(sizeof(bst<TBacking, T> *) * capacity);
			lengths = (uint32_t *)memory_alloc(sizeof(uint32_t) * capacity);
			for (size_t i = 0; i < capacity; i++)
				{
				store[i] = NULL;
				lengths[i] = 0;
				}
			}

		void insert(str key, T val)
			{
			unsigned int index = hash(key.c_str()) & (1 << 16) - 1;
			if (store[index] == NULL)
				{
				store[index] = new bst<TBacking, T>(key, val);
				lengths[index]++;
				}
			else
				store[index]->insert(key, val, &lengths[index]);
			}

		void *find(char *key)
			{
			unsigned int index = hash(key) & (1 << 16) - 1;
			if (store[index] == NULL)
				return NULL;

			uint32_t length = *(uint32_t *)store[index];

			uint32_t *vec = (uint32_t *)((char *)store[index] + sizeof(uint32_t));

			for (size_t i = 0; i < length; i++)
				if (strcmp(key, (char *)store[index] + vec[i*2]) == 0)
					return (char *)store[index] + vec[i*2+1];

			return NULL;
			}

		uint32_t write(char *buffer)
			{
			uint32_t count = 0;
			for (size_t i = 0; i < capacity; i++)
				if (store[i] != NULL)
					count++;

			((uint32_t *)buffer)[0] = count;
			char *at = buffer + sizeof(uint32_t) + sizeof(uint32_t) * count; // Ptrs to stores

			size_t offset = 1; // First index for length
			for (size_t i = 0; i < capacity; i++)
				if (store[i] != NULL)
					{
					char *start = at;

					((uint32_t *)at)[0] = lengths[i];
					at += sizeof(uint32_t);
					char *ptr_store = at; // All key, and val ptrs
					at += lengths[i] * 2 * sizeof(uint32_t); // Keys and postings
					store[i]->write(start, &ptr_store, &at);

					((uint32_t *)buffer)[offset++] = start - buffer;
					}

			return at - buffer;
			}

		static hash_table *read(char *buffer)
			{
			hash_table *h = new hash_table();
			h->capacity = 1 << 16;
			h->store = (bst<TBacking, T> **)memory_alloc(sizeof(bst<TBacking, T> *) * h->capacity);
			h->lengths = NULL;

			uint32_t count = ((uint32_t *)buffer)[0];

			uint32_t *stores = &((uint32_t *)buffer)[1];

			for (size_t i = 0; i < count; i++)
				{
				char *cell = buffer + stores[i];
				char *key = cell + ((uint32_t *)cell)[1];
				unsigned int index = hash(key) & (1 << 16) - 1;
				h->store[index] = (bst<TBacking, T> *)cell;
				}

			return h;
			}
	};
