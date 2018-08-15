/*
		STRING2.C
		---------
		Copyright (c) 2017 Vaughan Kitchen
		Released under the MIT license (https://opensource.org/licenses/MIT)
*/

#include <stdlib.h>
#include <string.h>
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
		dest->str = memory_realloc(dest->str, sizeof(*dest->str) * (dest->bytes + lenb + 1));
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
	struct string *s = memory_alloc(sizeof(*s));
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
	struct string *s = memory_alloc(sizeof(*s));
	s->str = strdup(str);
	s->bytes = strlen(str);
	return s;
	}
