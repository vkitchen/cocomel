#pragma once

#include <utility>
#include <stdint.h>
#include "dynamic_array.h"

class posting
	{
	private:
		uint32_t id;
		uint32_t id_capacity = 256;
		uint32_t id_length = 0;
		uint8_t *id_store;
		dynamic_array<uint8_t> counts;

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		posting();

		void append(uint32_t id);

		size_t write(char *buffer);

		dynamic_array<std::pair<size_t, double>> *decompress();
	};
