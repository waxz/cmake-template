#include "mathutil/mathutil.hpp"

#include <numeric>

namespace mathutil {

double mean(const std::vector<double>& values) {
    if (values.empty()) {
        return 0.0;
    }
    return std::accumulate(values.begin(), values.end(), 0.0) / static_cast<double>(values.size());
}

double clamp(double value, double lo, double hi) {
    return value < lo ? lo : (value > hi ? hi : value);
}

} // namespace mathutil
