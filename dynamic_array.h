#pragma once

#include <stdlib.h>
#include "memory.h"

template <typename T>
class dynamic_array
	{
	public:
		size_t capacity;
		size_t length;
		T *store;

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		dynamic_array()
			{
			capacity = 256;
			length = 0;
			store = (T *)malloc(capacity * sizeof(T));
			}

		void append(T val)
			{
			if (length == capacity)
				{
				capacity *= 2;
				store = (T *)realloc(store, capacity * sizeof(T));
				}
			store[length] = val;
			length++;
			}

		T *back()
			{
			return &store[length-1];
			}
	};