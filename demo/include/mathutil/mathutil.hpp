#pragma once

#include <vector>

namespace mathutil {

double mean(const std::vector<double>& values);
double clamp(double value, double lo, double hi);

} // namespace mathutil
