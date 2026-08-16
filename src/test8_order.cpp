// 实验 8：顺序调换 —— "测出来不对"的真凶是不是【谁先跑谁慢】(冷启动)，而不是 const？
// 用命令行参数决定先跑 const 还是先跑 auto。
#include <chrono>
#include <cstdio>
#include <cstring>
#include <cmath>

using namespace std::chrono;
volatile double sink = 0.0;

static void work(int n) {
    double s = 0;
    for (int i = 1; i <= n; ++i) s += std::sin((double)i) / (double)i;
    sink = s;
}

static double run_auto(int n) {
    auto t0 = high_resolution_clock::now();
    work(n);
    auto t1 = high_resolution_clock::now();
    return duration<double, std::milli>(t1 - t0).count();
}
static double run_const(int n) {
    const auto t0 = high_resolution_clock::now();
    work(n);
    const auto t1 = high_resolution_clock::now();
    return duration<double, std::milli>(t1 - t0).count();
}

int main(int argc, char** argv) {
    const int n = 2000000;
    bool const_first = (argc > 1 && std::strcmp(argv[1], "const-first") == 0);

    printf("顺序: %s\n", const_first ? "const auto 先跑" : "auto 先跑");
    double a, c;
    if (const_first) { c = run_const(n); a = run_auto(n); }
    else             { a = run_auto(n);  c = run_const(n); }
    printf("  第1次测量: %8.4f ms   <-- %s\n", const_first ? c : a,
           const_first ? "const auto" : "auto");
    printf("  第2次测量: %8.4f ms   <-- %s\n", const_first ? a : c,
           const_first ? "auto" : "const auto");
    printf("  比值: %.2fx\n", (const_first ? c : a) / (const_first ? a : c));

    printf("\n  加了 warmup 之后（各再测 5 轮）:\n");
    run_auto(n); run_const(n);   // warmup
    for (int i = 0; i < 5; ++i)
        printf("    auto=%8.4f ms   const auto=%8.4f ms\n", run_auto(n), run_const(n));
    return 0;
}
