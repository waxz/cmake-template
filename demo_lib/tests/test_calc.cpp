#include <cstdio>
#include <vector>

#include "calc/calc.hpp"

int main() {
    int failures = 0;
    if (calc::add(2, 3) != 5) {
        std::printf("FAILED: add\n");
        ++failures;
    }
    std::vector<double> values(1000, 0.5);
    if (calc::parallel_sum(values, 8) != 500.0) {
        std::printf("FAILED: parallel_sum\n");
        ++failures;
    }
    if (calc::parallel_sum({}, 4) != 0.0) {
        std::printf("FAILED: parallel_sum of empty input\n");
        ++failures;
    }
    std::printf("calc %s (%s): %s\n", calc::version(), calc::variant(), failures == 0 ? "passed" : "failed");
    return failures == 0 ? 0 : 1;
}
