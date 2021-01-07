/*
	GEN.C
	-----
	Copyright (c) 2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "file.h"
#include "str.h"

#include "fucs.h"

#define TABLE_END 0xE01FF
static char lookup_table[TABLE_END+1];

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
	*bytes_used = -1;
	return 0;
	}

struct tokenizer
	{
	size_t index;
	size_t length;
	char *document;
	};

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
	MINLETTER,
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

static int ishex(int c)
	{
	int uc = toupper(c);
	return isdigit(c) || ('A' <= uc && uc <= 'F');
	}

static void tokenizer_consume_line(struct tokenizer *t)
	{
	while (t->index < t->length && t->document[t->index] != '\n')
		t->index++;
	if (t->index < t->length)
		t->index++;
	}

static enum property_type tokenizer_get_property(struct tokenizer *t)
	{
	for (size_t i = 0; property_decode[i] != 0; i++)
		{
		if (strncmp(&t->document[t->index], property_decode[i], strlen(property_decode[i])) == 0)
			return i;
		}
	return -1;
	}

static enum token_type tokenizer_next(struct tokenizer *t, struct property *p)
	{
	p->start = 0;
	p->end = 0;
	p->property = OTHER;

	while (t->index < t->length && (t->document[t->index] == '#' || t->document[t->index] == '\r' || t->document[t->index] == '\n'))
		tokenizer_consume_line(t);

	/* start pass input */
	if (t->index < t->length && ishex(t->document[t->index]))
		{
		/* start of range */
		size_t num_end = t->index;
		while (num_end < t->length && ishex(t->document[num_end]))
			num_end++;
		t->document[num_end] = '\0';
		p->start = strtoul(&t->document[t->index], NULL, 16);
		t->index = num_end + 1;

		/* end of range */
		if (t->index < t->length && t->document[t->index] == '.')
			{
			t->index++;
			if (!ishex(t->document[t->index]))
				{
				fprintf(stderr, "ERROR: Can't find end of range\n");
				exit(1);
				}
			
			size_t num_end = t->index;
			while (num_end < t->length && ishex(t->document[num_end]))
				num_end++;
			t->document[num_end] = '\0';
			p->end = strtoul(&t->document[t->index], NULL, 16);
			t->index = num_end + 1;
			}
		else
			p->end = p->start;

		/* range type */
		/* find start of type */
		while (t->index < t->length && t->document[t->index] != ';')
			t->index++;
		if (t->index < t->length)
			t->index++;
		while (t->index < t->length && isspace(t->document[t->index]))
			t->index++;

		int property = tokenizer_get_property(t);
		if (property == -1)
			{
			fprintf(stderr, "ERROR: Can't pass property\n");
			exit(1);
			}
		p->property = property;

		/* next */
		tokenizer_consume_line(t);
		}

	/* exit condition */
	if (t->index == t->length)
		return END;

	return WORD;
	}

static void build_table(struct tokenizer t)
	{
	enum token_type type;
	struct property p;
	while ((type = tokenizer_next(&t, &p)) != END)
		{
		for (size_t i = p.start; i <= p.end; i++)
			lookup_table[i] = p.property;
		}
	}

int main()
	{
	char *break_data;
	size_t filesize = file_slurp("data/WordBreakProperty.txt", &break_data);
	if (filesize == 0 || break_data == NULL)
		{
		fprintf(stderr, "Failed to open file 'WordBreakProperty.txt' for reading");
		exit(1);
		}
	struct tokenizer t;
	t.index = 0;
	t.length = filesize;
	t.document = break_data;
	build_table(t);

	FILE *fh = fopen("lookup_table.h", "w");
	if (fh == NULL)
		{
		fprintf(stderr, "ERROR: Failed to open lookup_table.h for writing\n");
		exit(1);
		}

	fputs("#ifndef LOOKUP_TABLE_H\n", fh);
	fputs("#define LOOKUP_TABLE_H\n", fh);
	fputs("\n", fh);
	fputs("#define TABLE_END 0xE01FF\n", fh);
	fputs("static char lookup_table[TABLE_END+1] =\n", fh);

	int has_printed = 0;
	int line_length = 0;
	for (size_t i = 0; i < TABLE_END; i++)
		{
		if (lookup_table[i] != 0)
			{
			if (!has_printed)
				{
				has_printed = 1;
				line_length += fprintf(fh, "{ [%zd] = %d", i, lookup_table[i]);
				}
			else if (line_length == 0)
				line_length += fprintf(fh, ", [%zd] = %d", i, lookup_table[i]);
			else
				line_length += fprintf(fh, ", [%zd] = %d", i, lookup_table[i]);
			}
		if (line_length >= 80)
			{
			line_length = 0;
			fputs("\n", fh);
			}
		}
	fputs("\n};\n", fh);
	fputs("\n", fh);
	fputs("#endif\n", fh);

	return 0;
	}

