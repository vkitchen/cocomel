#pragma once

#include <utility>
#include <cstdint>
#include "dynamic_array.h"

class posting
	{
	private:
		size_t id;
		size_t id_capacity;
		size_t id_length;
		uint8_t *id_store;
		dynamic_array<uint8_t> *counts;

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		posting();

		void append(size_t id);

		size_t write(char *buffer);

		dynamic_array<std::pair<size_t, double>> *decompress();
	};
