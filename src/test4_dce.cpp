// 实验 4：真正会让 "measured performance 不对" 的那类原因 —— 负载被优化掉 / 被搬走。
// 和 const 无关，两种写法都会中招。
#include <chrono>
#include <cstdio>
#include <cmath>

using namespace std::chrono;

// 结果没人用 -> -O2 下整个循环可被删除
static double dead_workload(int n) {
    double s = 0;
    for (int i = 1; i <= n; ++i) s += std::sin((double)i) / (double)i;
    return s;
}

int main() {
    const int N = 5000000;
    printf("=== 实验 4：结果未被使用的负载（DCE 陷阱）===\n");

    {   // 非 const 写法
        auto t0 = steady_clock::now();
        dead_workload(N);                 // 返回值丢弃
        auto t1 = steady_clock::now();
        printf("auto       + 丢弃结果 : %10.4f ms\n",
               duration<double, std::milli>(t1 - t0).count());
    }
    {   // const 写法
        const auto t0 = steady_clock::now();
        dead_workload(N);
        const auto t1 = steady_clock::now();
        printf("const auto + 丢弃结果 : %10.4f ms\n",
               duration<double, std::milli>(t1 - t0).count());
    }
    {   // 用 volatile sink 挡住 DCE
        volatile double sink;
        auto t0 = steady_clock::now();
        sink = dead_workload(N);
        auto t1 = steady_clock::now();
        (void)sink;
        printf("auto       + volatile : %10.4f ms\n",
               duration<double, std::milli>(t1 - t0).count());
    }
    {
        volatile double sink;
        const auto t0 = steady_clock::now();
        sink = dead_workload(N);
        const auto t1 = steady_clock::now();
        (void)sink;
        printf("const auto + volatile : %10.4f ms\n",
               duration<double, std::milli>(t1 - t0).count());
    }
    return 0;
}
