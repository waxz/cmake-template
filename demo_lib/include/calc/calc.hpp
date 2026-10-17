#pragma once

#include <vector>

#include "calc/calc_export.h"

namespace calc {

CALC_EXPORT const char* version();

// "shared" or "static": which variant of the library was linked
CALC_EXPORT const char* variant();

CALC_EXPORT int add(int a, int b);

// Sums the values on several threads
CALC_EXPORT double parallel_sum(const std::vector<double>& values, unsigned threads = 4);

} // namespace calc
