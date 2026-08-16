// 实验 2：典型 benchmark 场景 —— 测一段【已知时长】的工作，看 const auto 会不会测错。
// 参照物：nanosleep 100ms（用 clock_gettime 独立校验）。
#include <chrono>
#include <cstdio>
#include <thread>
#include <ctime>
#include <cmath>

using namespace std::chrono;

// 真正干活、无法被优化掉的负载
volatile double sink = 0.0;
static void workload_busy(int iters) {
    double s = 0;
    for (int i = 1; i <= iters; ++i) s += std::sin((double)i) / (double)i;
    sink = s;
}

static double ref_ms(struct timespec a, struct timespec b) {
    return (b.tv_sec - a.tv_sec) * 1e3 + (b.tv_nsec - a.tv_nsec) / 1e6;
}

template <class Clock>
void bench(const char* name, int iters) {
    struct timespec r0, r1;

    // --- 非 const ---
    clock_gettime(CLOCK_MONOTONIC, &r0);
    auto t0 = Clock::now();
    workload_busy(iters);
    auto t1 = Clock::now();
    clock_gettime(CLOCK_MONOTONIC, &r1);
    double m_auto = duration<double, std::milli>(t1 - t0).count();
    double m_ref_auto = ref_ms(r0, r1);

    // --- const ---
    clock_gettime(CLOCK_MONOTONIC, &r0);
    const auto c0 = Clock::now();
    workload_busy(iters);
    const auto c1 = Clock::now();
    clock_gettime(CLOCK_MONOTONIC, &r1);
    double m_const = duration<double, std::milli>(c1 - c0).count();
    double m_ref_const = ref_ms(r0, r1);

    printf("%-22s  auto=%9.4f ms (ref %9.4f)   const auto=%9.4f ms (ref %9.4f)\n",
           name, m_auto, m_ref_auto, m_const, m_ref_const);
}

template <class Clock>
void bench_sleep(const char* name) {
    // sleep 100ms —— 时长完全已知，任何偏差一眼可见
    auto t0 = Clock::now();
    std::this_thread::sleep_for(milliseconds(100));
    auto t1 = Clock::now();
    double m_auto = duration<double, std::milli>(t1 - t0).count();

    const auto c0 = Clock::now();
    std::this_thread::sleep_for(milliseconds(100));
    const auto c1 = Clock::now();
    double m_const = duration<double, std::milli>(c1 - c0).count();

    printf("%-22s  auto=%9.4f ms   const auto=%9.4f ms   (期望 ~100 ms)\n",
           name, m_auto, m_const);
}

int main(int argc, char**) {
    const int iters = 2000000;
    printf("=== 实验 2a：sleep 100ms（已知时长）===\n");
    for (int rep = 0; rep < 3; ++rep) {
        bench_sleep<system_clock>("system_clock");
        bench_sleep<steady_clock>("steady_clock");
        bench_sleep<high_resolution_clock>("high_resolution_clock");
    }
    printf("\n=== 实验 2b：计算负载 + clock_gettime 独立参照 ===\n");
    for (int rep = 0; rep < 3; ++rep) {
        bench<system_clock>("system_clock", iters);
        bench<steady_clock>("steady_clock", iters);
        bench<high_resolution_clock>("high_resolution_clock", iters);
        printf("\n");
    }
    (void)argc;
    return 0;
}
