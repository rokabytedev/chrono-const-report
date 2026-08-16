#!/bin/bash
# 在 x86_64 Linux 上用 cling（Cling C++ 解释器，xeus-cling 的底座）复现
# 「顶层 const auto 取两个 timestamp」的场景。
set -x
# 容器里缺 glibc 开发头（features.h），cling 的 #include <chrono> 会挂
apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq libc6-dev >/dev/null 2>&1
ls /usr/include/features.h || echo "features.h 仍缺失"
micromamba install -y -q -n base -c conda-forge cling 2>&1 | tail -5
export PATH=/opt/conda/bin:$PATH
which cling || { echo "cling 安装失败"; exit 1; }
cling --version
echo '#include <chrono>' | cling 2>&1 | head -5
echo "=== 冒烟测试结束 ==="

echo "############ 场景 1：逐条输入（模拟 Jupyter 一行一个 cell）############"

echo "--- 1a: const auto ---"
cling 2>&1 <<'EOF'
#include <chrono>
#include <cstdio>
#include <cmath>
using namespace std::chrono;
double sink = 0;
void work(int n){ double s=0; for(int i=1;i<=n;++i) s+=std::sin((double)i)/i; sink=s; }
const auto t0 = steady_clock::now();
work(2000000);
const auto t1 = steady_clock::now();
printf("t0 tick = %lld\n", (long long)t0.time_since_epoch().count());
printf("t1 tick = %lld\n", (long long)t1.time_since_epoch().count());
printf("CONST duration = %lld ns\n", (long long)duration_cast<nanoseconds>(t1-t0).count());
.q
EOF

echo "--- 1b: auto ---"
cling 2>&1 <<'EOF'
#include <chrono>
#include <cstdio>
#include <cmath>
using namespace std::chrono;
double sink = 0;
void work(int n){ double s=0; for(int i=1;i<=n;++i) s+=std::sin((double)i)/i; sink=s; }
auto t0 = steady_clock::now();
work(2000000);
auto t1 = steady_clock::now();
printf("t0 tick = %lld\n", (long long)t0.time_since_epoch().count());
printf("t1 tick = %lld\n", (long long)t1.time_since_epoch().count());
printf("AUTO  duration = %lld ns\n", (long long)duration_cast<nanoseconds>(t1-t0).count());
.q
EOF

echo "############ 场景 2：两种写法在同一个 session 里交替 ############"
cling 2>&1 <<'EOF'
#include <chrono>
#include <cstdio>
#include <cmath>
using namespace std::chrono;
double sink = 0;
void work(int n){ double s=0; for(int i=1;i<=n;++i) s+=std::sin((double)i)/i; sink=s; }
auto a0 = steady_clock::now();
work(2000000);
auto a1 = steady_clock::now();
const auto c0 = steady_clock::now();
work(2000000);
const auto c1 = steady_clock::now();
printf("AUTO  = %lld ns\n", (long long)duration_cast<nanoseconds>(a1-a0).count());
printf("CONST = %lld ns\n", (long long)duration_cast<nanoseconds>(c1-c0).count());
printf("a0=%lld a1=%lld c0=%lld c1=%lld\n", (long long)a0.time_since_epoch().count(), (long long)a1.time_since_epoch().count(), (long long)c0.time_since_epoch().count(), (long long)c1.time_since_epoch().count());
.q
EOF

echo "############ 场景 3：重复求值同一个 const 顶层变量 ############"
cling 2>&1 <<'EOF'
#include <chrono>
#include <cstdio>
using namespace std::chrono;
const auto k = steady_clock::now();
printf("read 1: %lld\n", (long long)k.time_since_epoch().count());
printf("read 2: %lld\n", (long long)k.time_since_epoch().count());
printf("read 3: %lld\n", (long long)k.time_since_epoch().count());
.q
EOF
