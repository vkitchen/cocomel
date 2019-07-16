#pragma once

#include "memory.h"
#include "str.h"

enum token_type {DOCNO, WORD, END};

class tokenizer
	{
	private:
		size_t index = 0;
		size_t length;
		char *document;

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		void init(char *doc, size_t len)
			{
			document = doc;
			length = len;
			}

		enum token_type next(str buffer);
	};
