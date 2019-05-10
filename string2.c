/*
		STRING2.C
		---------
		Copyright (c) 2017 Vaughan Kitchen
		Released under the MIT license (https://opensource.org/licenses/MIT)
*/

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "memory.h"
#include "string2.h"

/*
	STRING_APPEND_C()
	-----------------
*/
void string_append_c(struct string *dest, char *src)
	{
	size_t lenb = strlen(src);
	if (dest->str == NULL)
		{
		dest->str = strdup(src);
		dest->bytes = lenb;
		}
	else
		{
		dest->str = realloc(dest->str, sizeof(*dest->str) * (dest->bytes + lenb + 1));
		while (*src != '\0')
			dest->str[dest->bytes++] = *src++;
		dest->str[dest->bytes] = '\0';
		}
	}

/*
	STRING_FREE()
	-------------
*/
void string_free(struct string *str)
	{
	if (str->str != NULL)
		free(str->str);
	free(str);
	}

/*
	STRING_NEW()
	------------
*/
struct string *string_new()
	{
	struct string *s = malloc(sizeof(*s));
	s->str = NULL;
	s->bytes = 0;
	return s;
	}

/*
	STRING_NEW_C()
	--------------
*/
struct string *string_new_c(char *str)
	{
	struct string *s = malloc(sizeof(*s));
	s->str = strdup(str);
	s->bytes = strlen(str);
	return s;
	}

/*
	STRING_COPY_C()
	---------------
*/
size_t string_copy_c(char *dest, char *src)
	{
	size_t offset = 0;
	while (src[offset] != '\0')
		{
		dest[offset] = src[offset];
		offset++;
		}
	dest[offset] = '\0';
	offset++;
	return offset;
	}

/*
	STRING_UPPERCASE_C()
	--------------------
*/
void string_uppercase_c(char *str)
	{
	while ((*str = toupper(*str)))
		++str;
	}
