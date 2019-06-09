/*
		STRING2.H
		---------
		Copyright (c) 2017 Vaughan Kitchen
		Released under the MIT license (https://opensource.org/licenses/MIT)
*/
/*!
	@file
	@brief Define a String type more useful than cstrings and helpers around that type
	@author Vaughan Kitchen
	@copyright 2017 Vaughan Kitchen
*/

#pragma once

struct string
	{
		size_t bytes;	//!< The length of the string in bytes not including the termininating null byte
		char *str;		//!< Pointer to the underlying array of chars
	};

/*
	STRING_APPEND_C()
	-----------------
*/
/*!
		@brief Appends one string on to another
		@param dest [in,out] String that gets add to
		@param src [in] What is being added on
*/
void string_append_c(struct string *dest, char *src);

/*
	STRING_FREE()
	-------------
*/
/*!
		@brief Frees a string object
		@param str [in] String to be freed
		@return Pointer to the allocated memory or NULL on error
*/
void string_free(struct string *str);

/*
	STRING_NEW()
	------------
*/
/*!
		@brief Creates a new empty string object
		@return An empty string object
*/
struct string *string_new();

/*
	STRING_NEW_C()
	--------------
*/
/*!
		@brief Creates a new string object from a cstring
		@param str [in] String to use in creation
		@return String object
*/
struct string *string_new_c(char *str);

/*
	STRING_COPY_C()
	---------------
*/
/*!
		@brief Copies a cstring from src to dest
		@param src [in] String to copy
		@param dest [out] Buffer to copy to
		@return Number of characters copied
*/
size_t string_copy_c(char *dest, char *src);

/*
	STRING_UPPERCASE_C()
	--------------------
*/
/*!
		@brief Inplace uppercasing of a cstring
		@param str [in,out] String to uppercase
*/
void string_uppercase_c(char *str);

/*
	STRING_S_DUP()
	--------------
*/
/*!
		@brief Duplicates special type string where first four bytes contain the length.
		@param str [in] String to copy
		@return Duplicated string as a cstring
*/
char *string_s_dup(char *str);
