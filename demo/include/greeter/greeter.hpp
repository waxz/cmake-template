#pragma once

#include <string>

#include "greeter/greeter_export.h"

namespace greeter {

GREETER_EXPORT std::string greet(const std::string& name);
GREETER_EXPORT double average_score(double a, double b, double c);

} // namespace greeter
