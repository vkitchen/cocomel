#include "bst.h"
#include "memory.h"

#include "hash_table.h"

static inline uint32_t hash(char *key)
	{
	uint32_t result = 0;
	
	while (*key != '\0')
		result = (*key++ + 31 * result);

	return result & (HTCAP - 1);
	}

void hash_table_init(struct hash_table *h)
	{
	for (size_t i = 0; i < HTCAP; i++)
		{
		h->store[i] = NULL;
		h->lengths[i] = 0;
		}
	}

void hash_table_insert(struct hash_table *h, struct str key, uint32_t val)
	{
	uint32_t index = hash(str_c(key));
	if (h->store[index] == NULL)
		{
		h->store[index] = memory_alloc(sizeof(struct bst));
		bst_init(h->store[index], key, val);
		h->lengths[index]++;
		}
	else
		bst_insert(h->store[index], key, val, &h->lengths[index]);
	}

struct posting *hash_table_find(struct hash_table *h, char *key)
	{
			uint32_t index = hash(key);
			if (h->store[index] == NULL)
				return NULL;

			uint32_t length = *(uint32_t *)h->store[index];

			uint32_t *vec = (uint32_t *)((char *)h->store[index] + sizeof(uint32_t));

			for (size_t i = 0; i < length; i++)
				if (string_cmp(key, (char *)h->store[index] + vec[i*2]) == 0)
					return (struct posting *)((char *)h->store[index] + vec[i*2+1]);

			return NULL;
	}

uint32_t hash_table_write(struct hash_table *h, char *buffer)
	{
			uint32_t count = 0;
			for (size_t i = 0; i < HTCAP; i++)
				if (h->store[i] != NULL)
					count++;

			((uint32_t *)buffer)[0] = count;
			char *at = buffer + sizeof(uint32_t) + sizeof(uint32_t) * count; // Ptrs to stores

			size_t offset = 1; // First index for length
			for (size_t i = 0; i < HTCAP; i++)
				if (h->store[i] != NULL)
					{
					char *start = at;

					((uint32_t *)at)[0] = h->lengths[i];
					at += sizeof(uint32_t);
					char *ptr_store = at; // All key, and val ptrs
					at += h->lengths[i] * 2 * sizeof(uint32_t); // Keys and postings
					at = bst_write(h->store[i], start, ptr_store, at);

					((uint32_t *)buffer)[offset++] = start - buffer;
					}

			return at - buffer;
	}

struct hash_table *hash_table_read(struct hash_table *h, char *buffer)
	{
			uint32_t count = ((uint32_t *)buffer)[0];

			uint32_t *stores = &((uint32_t *)buffer)[1];

			for (size_t i = 0; i < count; i++)
				{
				char *cell = buffer + stores[i];
				char *key = cell + ((uint32_t *)cell)[1];
				unsigned int index = hash(key);
				h->store[index] = (struct bst *)cell;
				}

			return h;
	}

