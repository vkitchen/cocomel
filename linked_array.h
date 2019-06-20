#pragma once

#include <stdlib.h>
#include "memory.h"

#define CHUNKSIZE 256

template <typename T>
class linked_array
	{
	public:
		class iterator
			{
			private:
				size_t index;
				linked_array *current;

			public:
				iterator(linked_array *current, size_t index) : index(index), current(current) {}

				bool operator !=(iterator &other)
					{
					return current != other.current;
					}

				T &operator *()
					{
					return current->store[index];
					}

				iterator &operator ++()
					{
					index++;
					if (index == current->chunk_length)
						{
						index = 0;
						current = current->next;
						}
					return *this;
					}
			};

	public:
		uint32_t length = 0;
		uint32_t chunk_length = 0;
		linked_array *last = this;
		linked_array *next = NULL;
		T store[CHUNKSIZE];

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		iterator begin()
			{
			if (chunk_length == 0)
				return end();
			else
				return iterator(this, 0);
			}

		iterator end()
			{
			return iterator(NULL, 0);
			}

		void append(T val)
			{
			if (last->chunk_length == CHUNKSIZE)
				{
				last->next = new linked_array<T>();
				last = last->next;
				}
			last->store[last->chunk_length] = val;
			last->chunk_length++;
			length++;
			}

		T *back()
			{
			return &last->store[last->chunk_length-1];
			}
	};
