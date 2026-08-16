// 实验 3：反汇编对照 —— 两个函数除了 const 之外完全一样，生成的机器码是否有差别？
#include <chrono>
using namespace std::chrono;

extern void work();

long long elapsed_nonconst() {
    auto t0 = steady_clock::now();
    work();
    auto t1 = steady_clock::now();
    return duration_cast<nanoseconds>(t1 - t0).count();
}

long long elapsed_const() {
    const auto t0 = steady_clock::now();
    work();
    const auto t1 = steady_clock::now();
    return duration_cast<nanoseconds>(t1 - t0).count();
}
