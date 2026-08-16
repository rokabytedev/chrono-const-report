// 实验 10：命名空间作用域的 const —— C++ 里 const 唯一真正改变语义的地方。
// const 在命名空间作用域给变量【内部链接】，且初始化发生在 main() 之前。
#include <chrono>
#include <cstdio>
#include <thread>

using namespace std::chrono;

const auto g_const_start = steady_clock::now();      // 内部链接，静态初始化期求值
      auto g_plain_start = steady_clock::now();      // 外部链接，静态初始化期求值

int main() {
    std::this_thread::sleep_for(milliseconds(200));
    const auto now = steady_clock::now();
    printf("=== 实验 10：命名空间作用域 ===\n");
    printf("  距 const auto 全局量: %8.2f ms\n",
           duration<double, std::milli>(now - g_const_start).count());
    printf("  距       auto 全局量: %8.2f ms\n",
           duration<double, std::milli>(now - g_plain_start).count());
    printf("  注: 两者都是【程序启动时刻】，不是 main 开始时刻。差异来自 const 的内部链接，\n");
    printf("      而不是数值错误 —— 放进头文件被多个 TU 包含时，每个 TU 会各有一份拷贝。\n");
    return 0;
}
