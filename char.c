#include "char.h"

/* all from musl*/

char char_isspace(char c)
	{
	return c == ' ' || (unsigned)c-'\t' < 5;
	}

char char_islower(char c)
	{
	return (unsigned)c-'a' < 26;
	}

char char_isupper(char c)
	{
	return (unsigned)c-'A' < 26;
	}

char char_isalpha(char c)
	{
	return ((unsigned)c|32)-'a' < 26;
	}

char char_isdigit(char c)
	{
	return (unsigned)c-'0' < 10;
	}

char char_tolower(char c)
	{
	if (char_isupper(c))
		return c | 32;

	return c;
	}

char char_toupper(char c)
	{
	if (char_islower(c))
		return c & 0x5f;
	
	return c;
	}

