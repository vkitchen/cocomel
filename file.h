/*
	FILE.H
	------
	Copyright (c) 2017-2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef FILE_H
#define FILE_H

#include <stddef.h>

size_t file_slurp(char const *filename, char **into);
size_t file_size(char const *filename);
int file_exists(char const *filename);

#endif

