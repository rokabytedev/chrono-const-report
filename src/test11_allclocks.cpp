// 实验 17：他说的是 "chrono::<AnyClock>::now()"。把 C++20 里所有标准 clock 都覆盖掉。
#include <chrono>
#include <cstdio>
#include <cmath>

using namespace std::chrono;
volatile double sink = 0.0;
static void work(int n) {
    double s = 0;
    for (int i = 1; i <= n; ++i) s += std::sin((double)i) / (double)i;
    sink = s;
}

template <class Clock>
void cmp(const char* name, int n) {
    { auto t0 = Clock::now(); work(n); auto t1 = Clock::now(); (void)t0; (void)t1; }   // warmup
    auto a0 = Clock::now(); work(n); auto a1 = Clock::now();
    const auto c0 = Clock::now(); work(n); const auto c1 = Clock::now();
    double ma = duration<double, std::milli>(a1 - a0).count();
    double mc = duration<double, std::milli>(c1 - c0).count();
    printf("%-16s is_steady=%d  auto=%8.4f ms   const auto=%8.4f ms   偏差=%+.2f%%\n",
           name, (int)Clock::is_steady, ma, mc, (mc - ma) / ma * 100.0);
}

int main() {
    const int n = 2000000;
    printf("=== 实验 17：所有标准 clock ===\n");
    cmp<system_clock>("system_clock", n);
    cmp<steady_clock>("steady_clock", n);
    cmp<high_resolution_clock>("high_resolution", n);
#if __cpp_lib_chrono >= 201907L
    cmp<utc_clock>("utc_clock", n);
    cmp<tai_clock>("tai_clock", n);
    cmp<gps_clock>("gps_clock", n);
    cmp<file_clock>("file_clock", n);
#else
    printf("(此 libc++ 未提供 C++20 的 utc/tai/gps/file_clock，__cpp_lib_chrono=%ld)\n", (long)__cpp_lib_chrono);
#endif
    return 0;
}
