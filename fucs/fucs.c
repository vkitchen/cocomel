#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "file.h"
#include "str.h"

#include "fucs.h"
#include "lookup_table.h"

/*
bytes	bits	first	last		byte1		byte2		byte3		byte4
1	7	U+0000	U+007F		0xxxxxxx
2	11	U+0080	U+07FF		110xxxxx	10xxxxxx
3	16	U+0800	U+FFFF		1110xxxx	10xxxxxx	10xxxxxx
4	21	U+10000	U+10FFFF	11110xxx	10xxxxxx	10xxxxxx	10xxxxxx
*/
uint32_t uchar(char *txt, int *bytes_used)
	{
	uint32_t out = 0;
	if ((txt[0] & (1 << 7)) == 0)
		{
		if (bytes_used != NULL)
			*bytes_used = 1;
		return txt[0];
		}
	if ((txt[0] & ((8 - 1) << 5)) == (4 - 1) << 6)
		{
		if (bytes_used != NULL)
			*bytes_used = 2;
		size_t byte1 = txt[0] & ((1 << 6) - 1);
		byte1 <<= 6;
		size_t byte2 = txt[1] & ((1 << 7) - 1);
		out = byte1 | byte2;
		return out;
		}
	if ((txt[0] & ((16 - 1) << 4)) == (8 - 1) << 5)
		{
		if (bytes_used != NULL)
			*bytes_used = 3;
		size_t byte1 = txt[0] & ((1 << 4) - 1);
		byte1 <<= 12;
		size_t byte2 = txt[1] & ((1 << 6) - 1);
		byte2 <<= 6;
		size_t byte3 = txt[2] & ((1 << 6) - 1);
		out = byte1 | byte2 | byte3;
		return out;
		}
	if ((txt[0] & ((32 - 1) << 3)) == (16 - 1) << 4)
		{
		if (bytes_used != NULL)
			*bytes_used = 4;
		size_t byte1 = txt[0] & ((1 << 3) - 1);
		byte1 <<= 18;
		size_t byte2 = txt[1] & ((1 << 6) - 1);
		byte2 <<= 12;
		size_t byte3 = txt[2] & ((1 << 6) - 1);
		byte3 <<= 6;
		size_t byte4 = txt[3] & ((1 << 6) - 1);
		out = byte1 | byte2 | byte3 | byte4;
		return out;
		}
	if (bytes_used != NULL)
		*bytes_used = -1;
	return 0;
	}

struct tokenizer
	{
	size_t index;
	size_t length;
	char *document;
	};

// TODO use these names in the gen program
enum property_type
	{
	OTHER,
	DOUBLE_QUOTE,
	SINGLE_QUOTE,
	HEBREW_LETTER,
	CR,
	LF,
	NEWLINE,
	EXTEND,
	REGIONAL_INDICATOR,
	FORMAT,
	KATAKANA,
	ALETTER,
	MIDLETTER,
	MIDNUM,
	MIDNUMLET,
	NUMERIC,
	EXTENDNUMLET,
	ZWJ,
	WSEGSPACE
	};

static const char* const property_decode[] =
	{
	"Other",
	"Double_Quote",
	"Single_Quote",
	"Hebrew_Letter",
	"CR",
	"LF",
	"Newline",
	"Extend",
	"Regional_Indicator",
	"Format",
	"Katakana",
	"ALetter",
	"MidLetter",
	"MidNum",
	"MidNumLet",
	"Numeric",
	"ExtendNumLet",
	"ZWJ",
	"WSegSpace",
	0
	};

struct property
	{
	size_t start;
	size_t end;
	size_t property;
	};

struct tokenizer *fucs_parser_new(char *document)
	{
	struct tokenizer *t = malloc(sizeof(struct tokenizer));
	t->index = 0;
	t->length = strlen(document);
	t->document = document;
	return t;
	}

#define AHLETTER(c) (lookup_table[c] == ALETTER || lookup_table[c] == HEBREW_LETTER)
#define MIDNUMLETQ(c) (lookup_table[c] == MIDNUMLET || lookup_table[c] == SINGLE_QUOTE)

enum token_type fucs_parser_next(struct tokenizer *t, struct str buffer)
	{
	size_t index = t->index;
	int bytes_used = 0;
	int bytes_next_used = 0;
	size_t c = 0;

	if (index < t->length)
		{
		c = uchar(&t->document[index], &bytes_used);
		index += bytes_used;
		}
	else
		return END;

	while (index < t->length)
		{
		size_t nextc = uchar(&t->document[index], &bytes_used);
		size_t nextnextc = uchar(&t->document[index + bytes_used], &bytes_next_used);

		// Do not break within CRLF.
		// WB3
		if (lookup_table[c] == CR && lookup_table[nextc] == LF)
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// Otherwise break before and after Newlines (including CR and LF).
		// WB3a
		if (lookup_table[c] == NEWLINE || lookup_table[c] == CR || lookup_table[c] == LF)
			{
			string_n_copy(str_c(buffer), &t->document[t->index], index - t->index + 1);
			str_resize(buffer, index - t->index);
			t->index = index;
			return WORD;
			}

		// TODO implement this rule?
		// WB3b

		// TODO what is an Extended Pictographic?
		// Do not break within emoji zwj sequences.
		// WB3c

		// Keep horizontal whitespace together.
		// WB3d
		if (lookup_table[c] == WSEGSPACE && lookup_table[nextc] == WSEGSPACE)
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// Ignore Format and Extend Characters, except after sot, CR, LF, and Newline.
		// This also has the effect of Any x (Format | Extend | ZWJ)
		// WB4

		// Do not break between most letters.
		// WB5
		if (AHLETTER(c) && AHLETTER(nextc))
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// Do not break letters across certain punctuation.
		// WB6 & WB7
		if (AHLETTER(c) && (lookup_table[nextc] == MIDLETTER || MIDNUMLETQ(nextc)) && AHLETTER(nextnextc))
			{
			c = nextnextc;
			index += bytes_used + bytes_next_used;
			continue;
			}

		// WB7a
		if (lookup_table[c] == HEBREW_LETTER && lookup_table[nextc] == SINGLE_QUOTE)
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// WB7b & WB7c
		if (lookup_table[c] == HEBREW_LETTER && lookup_table[nextc] == DOUBLE_QUOTE && lookup_table[nextnextc] == HEBREW_LETTER)
			{
			c = nextnextc;
			index += bytes_used + bytes_next_used;
			continue;
			}

		// Do not break within sequences of digits, or digits adjacent to letters ("3a", or "A3").
		// WB8
		if (lookup_table[c] == NUMERIC && lookup_table[nextc] == NUMERIC)
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// WB9
		if (AHLETTER(c) && lookup_table[nextc] == NUMERIC)
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// WB10
		if (lookup_table[c] == NUMERIC && AHLETTER(nextc))
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// Do not break within sequences, such as "3.2" or "3,456.789".
		// WB11 & WB12
		if (lookup_table[c] == NUMERIC && (lookup_table[nextc] == MIDNUM || MIDNUMLETQ(nextc)) && lookup_table[nextnextc] == NUMERIC)
			{
			c = nextnextc;
			index += bytes_used + bytes_next_used;
			continue;
			}

		// Do not break between Katakana.
		// WB13
		if (lookup_table[c] == KATAKANA && lookup_table[nextc] == KATAKANA)
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// Do not break from extenders.
		// WB13a
		if ((AHLETTER(c) || lookup_table[c] == NUMERIC || lookup_table[c] == KATAKANA || lookup_table[c] == EXTENDNUMLET) && lookup_table[nextc] == EXTENDNUMLET)
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// WB13b
		if (lookup_table[c] == EXTENDNUMLET && (AHLETTER(nextc) || lookup_table[nextc] == NUMERIC || lookup_table[nextc] == KATAKANA))
			{
			c = nextc;
			index += bytes_used;
			continue;
			}

		// TODO is this one or more?
		// Do not break within emoji flag sequences. That is, do not break between
		// regional indicatior (RI) symbols if there is an odd number of RI
		// characters before the break point.
		// WB15
		// WB16

		// Otherwise, break everywhere (including around ideographs).
		// WB999
		string_n_copy(str_c(buffer), &t->document[t->index], index - t->index + 1);
		str_resize(buffer, index - t->index);
		t->index = index;
		return WORD;
		// c = nextc;
		// index += bytes_used;
		}
	return END;
	}

void fucs_print()
	{
	size_t i, j;
	for (i = 0; i < TABLE_END; i++)
		{
		for (j = i; j+1 < TABLE_END && lookup_table[j+1] == lookup_table[i]; j++)
			;
		printf("%04lX..%04lX\t ; %s\n", i, j, property_decode[(int)lookup_table[i]]);
		i = j;
		}
	}

