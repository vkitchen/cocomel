/*
		MEMORY.C
		--------
		Copyright (c) 2017 Vaughan Kitchen
		Released under the MIT license (https://opensource.org/licenses/MIT)
*/

#include <stdlib.h>
#include <stdio.h>
#include "memory.h"

/*
	MEMORY_ALLOC()
	--------------
*/
void *memory_alloc(size_t size)
	{
	void *p = malloc(size);
	if (p == NULL)
		{
		fprintf(stderr, "ERROR: memory_alloc() Failed to allocate %zd bytes memory", size);
		exit(1);
		}
	return p;
	}

/*
	MEMORY_REALLOC()
	----------------
*/
void *memory_realloc(void *ptr, size_t size)
	{
	void *p = realloc(ptr, size);
	if (p == NULL)
		{
		fprintf(stderr, "ERROR: memory_realloc() Failed to reallocate %zd bytes memory", size);
		exit(1);
		}
	return p;
	}
