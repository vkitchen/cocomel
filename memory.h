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

#ifndef MEMORY_H
#define MEMORY_H

#include <stddef.h>

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

#endif

