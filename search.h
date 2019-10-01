#pragma once

#include "dynamic_array.h"

// XXX WARNING not intended to be called multiple times
dynamic_array<std::pair<size_t, double>> *search(char *index, char *line);

