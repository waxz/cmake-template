#include "greeter/greeter.hpp"

#include "mathutil/mathutil.hpp"

namespace greeter {

std::string greet(const std::string& name) {
    return "Hello, " + name + "!";
}

double average_score(double a, double b, double c) {
    return mathutil::clamp(mathutil::mean({a, b, c}), 0.0, 100.0);
}

} // namespace greeter
