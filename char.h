#ifndef CHAR_H
#define CHAR_H

/* all from musl */

static inline char char_isspace(char c)
	{
	return c == ' ' || (unsigned)c-'\t' < 5;
	}

static inline char char_islower(char c)
	{
	return (unsigned)c-'a' < 26;
	}

static inline char char_isupper(char c)
	{
	return (unsigned)c-'A' < 26;
	}

static inline char char_isalpha(char c)
	{
	return ((unsigned)c|32)-'a' < 26;
	}

static inline char char_isdigit(char c)
	{
	return (unsigned)c-'0' < 10;
	}

static inline char char_tolower(char c)
	{
	if (char_isupper(c))
		return c | 32;

	return c;
	}

static inline char char_toupper(char c)
	{
	if (char_islower(c))
		return c & 0x5f;

	return c;
	}

#endif

