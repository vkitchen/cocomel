#pragma once

#include "memory.h"
#include "str.h"

enum token_type {DOCNO, WORD, END};

class tokenizer
	{
	private:
		size_t length;
		size_t index;
		char *document;

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		tokenizer(char *str, size_t length);

		enum token_type next(str buffer);
	};
