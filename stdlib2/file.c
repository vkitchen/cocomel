/*
		FILE.C
		------
		Copyright (c) 2017 Vaughan Kitchen
		Released under the MIT license (https://opensource.org/licenses/MIT)
*/

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include "file.h"
#include "memory.h"
#include "string2.h"

/*
	FILE_SLURP_BUFFER_C()
	---------------------
*/
size_t file_slurp_buffer_c(char *filename, char *buffer, size_t len)
	{
	FILE *fh;
	struct stat details;
	size_t file_length = 0;

	if ((fh = fopen(filename, "rb")) != NULL)
		{
		if (fstat(fileno(fh), &details) == 0)
			if ((file_length = details.st_size) != 0 && file_length < len)
				{
				buffer[file_length] = '\0';
				if (fread(&buffer[0], details.st_size, 1, fh) != 1)
					file_length = 0;
				}
		fclose(fh);
		}

	return file_length;
	}

/*
	FILE_SLURP_C()
	--------------
*/
struct string *file_slurp_c(char *filename)
	{
	FILE *fh;
	struct stat details;
	size_t file_length = 0;
	struct string *result = memory_alloc(sizeof(*result));

	if ((fh = fopen(filename, "rb")) != NULL)
		{
		if (fstat(fileno(fh), &details) == 0)
			if ((file_length = details.st_size) != 0)
				{
				result->str = memory_alloc(sizeof(*result->str) * (file_length + 1));
				result->bytes = file_length;
				result->str[result->bytes] = '\0';
				if (fread(&result->str[0], details.st_size, 1, fh) != 1)
					{
					free(result->str);
					result->str = NULL;
					result->bytes = 0;
					}
				}
		fclose(fh);
		}

	return result;
	}

/*
	FILE_EXISTS_C()
	---------------
*/
int file_exists_c(char *filename)
	{
	return access(filename, F_OK) != -1;
	}
