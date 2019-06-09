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

			char *ptr_store = (char *)store + (size_t)store[index];
			uint32_t length = *(uint32_t *)ptr_store;

			size_t *vec = (size_t *)(ptr_store + sizeof(uint32_t));

			for (size_t i = 0; i < length; i++)
				if (strcmp(key, (char *)store + vec[i*2]) == 0)
					return (char *)store + vec[i*2+1];

			return NULL;
			}

		size_t write(char *buffer)
			{
			size_t delta = sizeof(bst<TBacking, T> *) * capacity;
			for (size_t i = 0; i < capacity; i++)
				if (store[i] != NULL)
					{
					size_t start = delta;

					((uint32_t *)&buffer[delta])[0] = lengths[i];
					delta += sizeof(uint32_t);
					size_t ptr_offset = lengths[i] * 2 * sizeof(char *);
					char *ptr_store = &buffer[delta];
					char *data_store = &buffer[delta + ptr_offset];
					store[i]->write(&ptr_store, &data_store);
					delta += data_store - &buffer[delta];

					store[i] = (bst<TBacking, T> *)start;
					}

			memcpy(&buffer[0], store, sizeof(bst<TBacking, T> *) * capacity);

			return delta;
			}

		static hash_table *read(char *buffer)
			{
			hash_table *h = new hash_table();
			h->capacity = 1 << 16;
			h->store = (bst<TBacking, T> **)buffer;
			h->lengths = NULL;
			for (size_t i = 0; i < h->capacity; i++)
				{

				if (h->store[i] == NULL)
					continue;

				uint32_t length = *(uint32_t *)(buffer + (size_t)h->store[i]);
				char *ptr_store = buffer + (size_t)h->store[i] + sizeof(uint32_t);

				for (size_t j = 0; j < length * 2; j++)
					{
					((size_t *)ptr_store)[0] = ptr_store + ((size_t *)ptr_store)[0] - buffer;
					ptr_store += sizeof(size_t);
					}

				}
			return h;
			}
	};
