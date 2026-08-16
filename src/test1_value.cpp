// 实验 1：const auto vs auto —— 返回的时间点数值本身是否正确？
// 对每种 clock，交替用 const auto / auto 取 now()，打印原始 tick 值和单调性。
#include <chrono>
#include <cstdio>
#include <cstdint>

using namespace std::chrono;

template <class Clock>
void raw_values(const char* name) {
    // 交错采样：c1(const) a1(auto) c2(const) a2(auto) ...
    const auto c1 = Clock::now();
    auto       a1 = Clock::now();
    const auto c2 = Clock::now();
    auto       a2 = Clock::now();
    const auto c3 = Clock::now();

    auto tick = [](typename Clock::time_point tp) -> long long {
        return static_cast<long long>(tp.time_since_epoch().count());
    };

    printf("--- %s (period = %lld/%lld s, is_steady=%d) ---\n", name,
           (long long)Clock::period::num, (long long)Clock::period::den,
           (int)Clock::is_steady);
    printf("  const c1 = %lld\n", tick(c1));
    printf("  auto  a1 = %lld   (a1-c1 = %lld)\n", tick(a1), tick(a1) - tick(c1));
    printf("  const c2 = %lld   (c2-a1 = %lld)\n", tick(c2), tick(c2) - tick(a1));
    printf("  auto  a2 = %lld   (a2-c2 = %lld)\n", tick(a2), tick(a2) - tick(c2));
    printf("  const c3 = %lld   (c3-a2 = %lld)\n", tick(c3), tick(c3) - tick(a2));
    printf("  单调递增(每步>=0)? %s\n",
           (tick(a1) >= tick(c1) && tick(c2) >= tick(a1) &&
            tick(a2) >= tick(c2) && tick(c3) >= tick(a2)) ? "YES" : "NO !!!");
    printf("\n");
}

int main() {
    printf("=== 实验 1：now() 返回值本身 ===\n\n");
    raw_values<system_clock>("system_clock");
    raw_values<steady_clock>("steady_clock");
    raw_values<high_resolution_clock>("high_resolution_clock");
    printf("high_resolution_clock is steady_clock ? %s\n",
           std::is_same<high_resolution_clock, steady_clock>::value ? "YES" : "NO");
    printf("high_resolution_clock is system_clock ? %s\n",
           std::is_same<high_resolution_clock, system_clock>::value ? "YES" : "NO");
    return 0;
}
