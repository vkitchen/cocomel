#pragma once

#include "memory.h"

enum token_type {DOCNO, WORD, END};

class tokenizer
	{
	private:
		size_t length;
		size_t index;
		char *document;

	private:
		inline void advance();

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		tokenizer(char *str, size_t length);

		enum token_type next(char *buffer);
	};
