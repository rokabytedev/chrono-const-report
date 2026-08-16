// 实验 18：统计学对照 —— 交替采样 N 轮，比中位数和分布，避免单点噪声误导。
#include <chrono>
#include <cstdio>
#include <cmath>
#include <vector>
#include <algorithm>

using namespace std::chrono;
volatile double sink = 0.0;

static void work(int n) {
    double s = 0;
    for (int i = 1; i <= n; ++i) s += std::sin((double)i) / (double)i;
    sink = s;
}

template <class Clock>
static double m_auto(int n) {
    auto t0 = Clock::now(); work(n); auto t1 = Clock::now();
    return duration<double, std::milli>(t1 - t0).count();
}
template <class Clock>
static double m_const(int n) {
    const auto t0 = Clock::now(); work(n); const auto t1 = Clock::now();
    return duration<double, std::milli>(t1 - t0).count();
}

static double pct(std::vector<double> v, double p) {
    std::sort(v.begin(), v.end());
    return v[(size_t)(p * (v.size() - 1))];
}

template <class Clock>
void run(const char* name, int n, int reps) {
    std::vector<double> A, C;
    // warmup
    for (int i = 0; i < 5; ++i) { m_auto<Clock>(n); m_const<Clock>(n); }
    // 交替采样，抵消漂移
    for (int i = 0; i < reps; ++i) {
        if (i % 2 == 0) { A.push_back(m_auto<Clock>(n));  C.push_back(m_const<Clock>(n)); }
        else            { C.push_back(m_const<Clock>(n)); A.push_back(m_auto<Clock>(n));  }
    }
    double ma = pct(A, 0.5), mc = pct(C, 0.5);
    printf("%-16s N=%d  auto: p50=%7.4f p25=%7.4f p75=%7.4f min=%7.4f\n",
           name, reps, ma, pct(A, 0.25), pct(A, 0.75), pct(A, 0.0));
    printf("%-16s        const: p50=%7.4f p25=%7.4f p75=%7.4f min=%7.4f\n", "", mc, pct(C, 0.25), pct(C, 0.75), pct(C, 0.0));
    printf("%-16s        中位数差异: %+.3f%%   最小值差异: %+.3f%%\n\n", "",
           (mc - ma) / ma * 100.0, (pct(C, 0.0) - pct(A, 0.0)) / pct(A, 0.0) * 100.0);
}

int main() {
    const int n = 2000000;
    const int reps = 200;
    printf("=== 实验 18：交替采样 %d 轮的统计对照 ===\n", reps);
    printf("（p50=中位数，min=最小值，最能代表无干扰下的真实耗时）\n\n");
    run<system_clock>("system_clock", n, reps);
    run<steady_clock>("steady_clock", n, reps);
    run<high_resolution_clock>("high_resolution", n, reps);
    return 0;
}
