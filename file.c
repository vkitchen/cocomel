/*
	FILE.C
	------
	Copyright (c) 2017-2019, 2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include "file.h"

size_t file_slurp(char const *filename, char **into)
	{
	FILE *fh;
	struct stat details;
	size_t file_length = 0;

	if ((fh = fopen(filename, "rb")) != NULL)
		{
		if (fstat(fileno(fh), &details) == 0)
			if ((file_length = details.st_size) != 0)
				{
				*into = (char *)malloc(file_length + 1);
				(*into)[file_length] = '\0';
				if (fread(*into, details.st_size, 1, fh) != 1)
					{
					free(*into);
					file_length = 0;
					}
				}
		fclose(fh);
		}

	return file_length;
	}

size_t file_size(char const *filename)
	{
	struct stat details;
	stat(filename, &details);
	return details.st_size;
	}

int file_exists(char const *filename)
	{
	return access(filename, F_OK) != -1;
	}
