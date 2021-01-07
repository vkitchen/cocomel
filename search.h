/*
	SEARCH.H
	--------
	Copyright (c) 2019-2021 Vaughan Kitchen
	Released under the ISC license (https://opensource.org/licenses/ISC)
*/

#ifndef SEARCH_H
#define SEARCH_H

#include "dynamic_array_kv_64.h"

// XXX WARNING not intended to be called multiple times
struct dynamic_array_kv_64 *search(char *index, char *line);

#endif

