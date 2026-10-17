#include <cmath>
#include <cstdio>

#include "mathutil/mathutil.hpp"

static int failures = 0;

static void check(bool ok, const char* what) {
    if (!ok) {
        std::printf("FAILED: %s\n", what);
        ++failures;
    }
}

int main() {
    check(mathutil::mean({}) == 0.0, "mean of empty input is 0");
    check(std::fabs(mathutil::mean({1.0, 2.0, 3.0}) - 2.0) < 1e-12, "mean of 1,2,3 is 2");
    check(mathutil::clamp(5.0, 0.0, 1.0) == 1.0, "clamp high");
    check(mathutil::clamp(-5.0, 0.0, 1.0) == 0.0, "clamp low");
    check(mathutil::clamp(0.5, 0.0, 1.0) == 0.5, "clamp inside");
    std::printf("%s\n", failures == 0 ? "all tests passed" : "some tests failed");
    return failures == 0 ? 0 : 1;
}
