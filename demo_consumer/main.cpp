#include <cstdio>
#include <vector>

#include <calc/calc.hpp>

int main() {
    std::vector<double> values(100, 1.5);
    std::printf("calc %s (%s)\n", calc::version(), calc::variant());
    std::printf("add(40, 2) = %d\n", calc::add(40, 2));
    std::printf("parallel_sum = %.1f\n", calc::parallel_sum(values));
    return calc::add(40, 2) == 42 ? 0 : 1;
}
