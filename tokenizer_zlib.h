#pragma once

#include <zlib.h>
#include "tar.h"
#include "str.h"

class tokenizer_zlib
	{
	private:
		char header_buffer[sizeof(struct tar_header)];
		size_t index = 0;
		size_t length = 0;
		char *document = NULL;
		size_t document_max = 0;
		gzFile fd;

	private:
		enum token_type next_file(str buffer);

	public:
		static void *operator new(size_t size)
			{
			return memory_alloc(size);
			}

		void init(char *filename)
			{
			fd = gzopen(filename, "rb");
			}

		void cleanup()
			{
			gzclose(fd);
			}

		enum token_type next(str buffer);
	};
