/*
		MEMORY.H
		--------
		Copyright (c) 2017 Vaughan Kitchen
		Released under the MIT license (https://opensource.org/licenses/MIT)
*/
/*!
	@file
	@brief Error checking memory allocation
	@author Vaughan Kitchen
	@copyright 2017 Vaughan Kitchen
*/

#ifndef MEMORY_H_
#define MEMORY_H_

#include <stdlib.h>

/*
	MEMORY_ALLOC()
	--------------
*/
/*!
		@brief Allocate memory of specified size
		@param size [in] Number of bytes of memory to allocate
		@return Pointer to the allocated memory or NULL on error
*/
void *memory_alloc(size_t size);

/*
	MEMORY_REALLOC()
	----------------
*/
/*!
		@brief Alter the size of already allocated memory
		@param ptr [in] Pointer to previously allocated memory
		@param size [in] Number of bytes the chunk of memory should now be
		@return Pointer to the resized chunk of memory or NULL on error
*/
void *memory_realloc(void *ptr, size_t size);

#endif
