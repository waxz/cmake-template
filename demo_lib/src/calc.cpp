#include "calc/calc.hpp"

#include <algorithm>
#include <numeric>
#include <thread>

namespace calc {

const char* version() {
    return CALC_VERSION;
}

const char* variant() {
#ifdef CALC_STATIC_DEFINE
    return "static";
#else
    return "shared";
#endif
}

int add(int a, int b) {
    return a + b;
}

double parallel_sum(const std::vector<double>& values, unsigned threads) {
    threads = std::max(1u, std::min<unsigned>(threads, static_cast<unsigned>(values.size())));
    if (values.empty()) {
        return 0.0;
    }
    std::vector<double> partial(threads, 0.0);
    std::vector<std::thread> workers;
    const std::size_t chunk = (values.size() + threads - 1) / threads;
    for (unsigned t = 0; t < threads; ++t) {
        workers.emplace_back([&, t] {
            const std::size_t begin = std::min(values.size(), t * chunk);
            const std::size_t end = std::min(values.size(), begin + chunk);
            partial[t] = std::accumulate(values.begin() + static_cast<std::ptrdiff_t>(begin),
                                         values.begin() + static_cast<std::ptrdiff_t>(end), 0.0);
        });
    }
    for (auto& worker : workers) {
        worker.join();
    }
    return std::accumulate(partial.begin(), partial.end(), 0.0);
}

} // namespace calc
