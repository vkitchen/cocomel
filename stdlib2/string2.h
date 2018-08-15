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

#ifndef STRING_H_
#define STRING_H_

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
		@param dest [in] String that gets add to
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

#endif
