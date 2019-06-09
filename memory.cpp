/*
		MEMORY.C
		--------
		Copyright (c) 2017 Vaughan Kitchen
		Released under the MIT license (https://opensource.org/licenses/MIT)
*/

#include <stdlib.h>
#include <stdio.h>
#include "memory.h"

#define MAXMEM 256 * 1024 * 1024

static char *buffer;
static char *buffer_end;

/*
	MEMORY_ALLOC()
	--------------
*/
/* TODO this should probably deal with char * */
void *memory_alloc(size_t size)
	{
	size = (size + 8 - 1) & -8; // round to word size
	if (buffer == NULL || buffer + size >= buffer_end)
		{
		buffer = (char *)malloc(MAXMEM);
		buffer_end = buffer + MAXMEM;
		}
	char *out = buffer;
	if (buffer + size >= buffer_end)
		{
		fprintf(stderr, "ERROR: memory_alloc() Memory exhausted. Failed to allocate %zd bytes\n", size);
		exit(1);
		}
	buffer += size;
	return out;
	}
