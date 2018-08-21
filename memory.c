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

static void *buffer;
static void *buffer_end;

/*
	MEMORY_ALLOC()
	--------------
*/
void *memory_alloc(size_t size) {
	size = (size + 8 - 1) & -8; // round to word size
	if (buffer == NULL || buffer + size >= buffer_end) {
		buffer = malloc(MAXMEM);
		buffer_end = buffer + MAXMEM;
	}
	void *out = buffer;
	if (buffer + size >= buffer_end) {
		fprintf(stderr, "ERROR: memory_alloc() Memory exhausted. Failed to allocate %zd bytes\n", size);
		exit(1);
	}
	buffer += size;
	return out;
}

/*
	MEMORY_REALLOC()
	----------------
*/
void *memory_realloc(void *ptr, size_t size) {
	fprintf(stderr, "ERROR: memory_realloc() Failed to reallocate %zd bytes memory", size);
	exit(1);
}
