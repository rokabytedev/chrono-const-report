// 实验 5：now() 到底能不能被"常量折叠"？
// 如果能，它必须是 constant expression。试着强制要求它是。
#include <chrono>
using namespace std::chrono;

constexpr auto t = steady_clock::now();   // 期望：编译失败
int main() { return (int)t.time_since_epoch().count(); }
