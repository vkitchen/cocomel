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

#pragma once

/*
	FILE_SLURP()
	------------
*/
/*!
		@brief Reads an entire file and returns it as a string (C calling convention)
		@param filename [in] Filename to be read
		@return String containing the contents of the file
*/
size_t file_slurp(char const *filename, char **into);

size_t file_size(char const *filename);
