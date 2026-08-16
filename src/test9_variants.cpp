// 实验 9：把所有 const 相关的写法变体都测一遍，看有没有哪一种真的会出问题。
#include <chrono>
#include <cstdio>
#include <thread>
#include <cmath>

using namespace std::chrono;
using Clock = high_resolution_clock;

volatile double sink = 0.0;
static void work(int n) {
    double s = 0;
    for (int i = 1; i <= n; ++i) s += std::sin((double)i) / (double)i;
    sink = s;
}

static double v_auto(int n) {
    auto t0 = Clock::now(); work(n); auto t1 = Clock::now();
    return duration<double, std::milli>(t1 - t0).count();
}
static double v_const_auto(int n) {
    const auto t0 = Clock::now(); work(n); const auto t1 = Clock::now();
    return duration<double, std::milli>(t1 - t0).count();
}
static double v_auto_const(int n) {          // const 写在后面，等价写法
    auto const t0 = Clock::now(); work(n); auto const t1 = Clock::now();
    return duration<double, std::milli>(t1 - t0).count();
}
static double v_const_ref(int n) {           // const 引用绑定临时量（生命周期延长）
    const auto& t0 = Clock::now(); work(n); const auto& t1 = Clock::now();
    return duration<double, std::milli>(t1 - t0).count();
}
static double v_univ_ref(int n) {            // 万能引用
    auto&& t0 = Clock::now(); work(n); auto&& t1 = Clock::now();
    return duration<double, std::milli>(t1 - t0).count();
}
static double v_constexpr_qual(int n) {      // volatile 限定
    volatile auto t0 = Clock::now().time_since_epoch().count();
    work(n);
    volatile auto t1 = Clock::now().time_since_epoch().count();
    return (double)(t1 - t0) / 1e6;
}

// ---- 这个才是真正会出错的写法：static const ----
static double v_static_const(int n) {
    static const auto t0 = Clock::now();     // !! 只在第一次调用时初始化
    work(n);
    static const auto t1 = Clock::now();     // !!
    return duration<double, std::milli>(t1 - t0).count();
}

int main() {
    const int n = 2000000;
    // warmup
    v_auto(n); v_const_auto(n); v_auto_const(n); v_const_ref(n); v_univ_ref(n); v_constexpr_qual(n);

    printf("=== 实验 9：写法变体对照（各 5 轮，单位 ms）===\n");
    printf("%-22s %8s %8s %8s %8s %8s\n", "写法", "r1", "r2", "r3", "r4", "r5");
    struct { const char* name; double (*fn)(int); } vs[] = {
        {"auto",            v_auto},
        {"const auto",      v_const_auto},
        {"auto const",      v_auto_const},
        {"const auto&",     v_const_ref},
        {"auto&&",          v_univ_ref},
        {"volatile auto",   v_constexpr_qual},
    };
    for (auto& v : vs) {
        printf("%-22s", v.name);
        for (int i = 0; i < 5; ++i) printf(" %8.4f", v.fn(n));
        printf("\n");
    }

    printf("\n=== static const auto 的陷阱（同一函数连调 3 次）===\n");
    for (int i = 0; i < 3; ++i)
        printf("  第 %d 次调用: %10.4f ms  %s\n", i + 1, v_static_const(n),
               i == 0 ? "" : "<-- 时间点没有重新采样，结果失真");
    return 0;
}
