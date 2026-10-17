#include <atomic>
#include <fstream>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

#include "greeter/greeter.hpp"
#include "mathutil/mathutil.hpp"

#ifdef DEMO_HAS_FMT
#include <fmt/core.h>
#endif

int main(int argc, char** argv) {
    std::cout << greeter::greet("CMake") << '\n';
    std::cout << "average score: " << greeter::average_score(90.0, 120.0, 60.0) << '\n';

    std::atomic<int> counter{0};
    std::vector<std::thread> workers;
    for (int i = 0; i < 4; ++i) {
        workers.emplace_back([&counter] { counter += 1; });
    }
    for (auto& worker : workers) {
        worker.join();
    }
    std::cout << "threads finished: " << counter << '\n';

    // config/ is copied next to the executable at build and install time
    const std::string exe = argc > 0 ? argv[0] : "";
    const std::string dir = exe.substr(0, exe.find_last_of("/\\") + 1);
    std::ifstream config(dir + "config/demo.yaml");
    std::cout << "config found: " << (config ? "yes" : "no") << '\n';

#ifdef DEMO_HAS_FMT
    fmt::print("fmt says: {:.2f}\n", mathutil::mean({1.0, 2.0, 4.0}));
#endif
    return 0;
}
