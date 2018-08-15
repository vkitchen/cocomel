/*
		FILE.H
		------
		Copyright (c) 2017 Vaughan Kitchen
		Released under the MIT license (https://opensource.org/licenses/MIT)
*/
/*!
	@file
	@brief Utilities for dealing with file io
	@author Vaughan Kitchen
	@copyright 2017 Vaughan Kitchen
*/
#ifndef FILE_H_
#define FILE_H_

#include "string.h"

/*
	FILE_SLURP_BUFFER_C()
	---------------------
*/
/*!
		@brief Reads an entire file into a preallocated buffer (C calling convention)
		@param filename [in] Filename to be read
		@param buffer [in] Buffer to read into
		@param len [in] Maximum number of bytes that can be read before buffer overflows
		@return Number of bytes read
*/
size_t file_slurp_buffer_c(char *filename, char *buffer, size_t len);

/*
	FILE_SLURP_C()
	------------
*/
/*!
		@brief Reads an entire file and returns it as a string (C calling convention)
		@param filename [in] Filename to be read
		@return String containing the contents of the file
*/
struct string *file_slurp_c(char *filename);

/*
	FILE_EXISTS_C()
	---------------
*/
/*!
		@brief Checks whether a file exists on the filesystem (C calling convention)
		@param filename [in] Filename to check
*/
int file_exists_c(char *filename);

#endif
