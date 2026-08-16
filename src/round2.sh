#!/bin/bash
# 第二轮：把「t1 读成 0」这个异常隔离清楚，并确认它是否与 const 有关。
export PATH=/opt/conda/bin:$PATH
Q() { cling 2>&1 | grep -vE "Warning in cling|Possible C\+\+ standard|Extraction of runtime|^\*+|^\| |^$|Type C\+\+|introduction and demos|^\[cling\]"; }

echo "########## A/B/C/D：连续声明 vs 中间夹一条语句 × auto vs const ##########"
Q <<'EOF'
#include <chrono>
#include <cstdio>
using namespace std::chrono;
typedef steady_clock SC;
auto A0 = SC::now();
auto A1 = SC::now();
printf("A  auto  连续声明     : A0=%lld A1=%lld  diff=%lld\n", (long long)A0.time_since_epoch().count(), (long long)A1.time_since_epoch().count(), (long long)(A1-A0).count());
const auto C0 = SC::now();
const auto C1 = SC::now();
printf("C  const 连续声明     : C0=%lld C1=%lld  diff=%lld\n", (long long)C0.time_since_epoch().count(), (long long)C1.time_since_epoch().count(), (long long)(C1-C0).count());
auto B0 = SC::now();
printf("(中间夹一条语句)\n");
auto B1 = SC::now();
printf("B  auto  夹语句       : B0=%lld B1=%lld  diff=%lld\n", (long long)B0.time_since_epoch().count(), (long long)B1.time_since_epoch().count(), (long long)(B1-B0).count());
const auto D0 = SC::now();
printf("(中间夹一条语句)\n");
const auto D1 = SC::now();
printf("D  const 夹语句       : D0=%lld D1=%lld  diff=%lld\n", (long long)D0.time_since_epoch().count(), (long long)D1.time_since_epoch().count(), (long long)(D1-D0).count());
.q
EOF

echo
echo "########## E：同一个 cell 内（花括号块作用域）——最接近真实用法 ##########"
Q <<'EOF'
#include <chrono>
#include <cstdio>
#include <cmath>
using namespace std::chrono;
double sink=0;
void work(int n){ double s=0; for(int i=1;i<=n;++i) s+=std::sin((double)i)/i; sink=s; }
{ auto t0 = steady_clock::now(); work(2000000); auto t1 = steady_clock::now(); printf("E1 auto  同 cell: %lld ns\n", (long long)duration_cast<nanoseconds>(t1-t0).count()); }
{ const auto t0 = steady_clock::now(); work(2000000); const auto t1 = steady_clock::now(); printf("E2 const 同 cell: %lld ns\n", (long long)duration_cast<nanoseconds>(t1-t0).count()); }
{ auto t0 = steady_clock::now(); work(2000000); auto t1 = steady_clock::now(); printf("E3 auto  同 cell: %lld ns\n", (long long)duration_cast<nanoseconds>(t1-t0).count()); }
{ const auto t0 = steady_clock::now(); work(2000000); const auto t1 = steady_clock::now(); printf("E4 const 同 cell: %lld ns\n", (long long)duration_cast<nanoseconds>(t1-t0).count()); }
.q
EOF

echo
echo "########## F：函数内（完全正常的作用域）作为对照 ##########"
Q <<'EOF'
#include <chrono>
#include <cstdio>
#include <cmath>
using namespace std::chrono;
double sink=0;
void work(int n){ double s=0; for(int i=1;i<=n;++i) s+=std::sin((double)i)/i; sink=s; }
long long f_auto(){ auto t0=steady_clock::now(); work(2000000); auto t1=steady_clock::now(); return duration_cast<nanoseconds>(t1-t0).count(); }
long long f_const(){ const auto t0=steady_clock::now(); work(2000000); const auto t1=steady_clock::now(); return duration_cast<nanoseconds>(t1-t0).count(); }
f_auto(); f_auto();
printf("F1 auto  函数内: %lld ns\n", f_auto());
printf("F2 const 函数内: %lld ns\n", f_const());
printf("F3 auto  函数内: %lld ns\n", f_auto());
printf("F4 const 函数内: %lld ns\n", f_const());
.q
EOF

echo
echo "########## G：最小复现 —— 顶层声明后紧跟一条语句 ##########"
Q <<'EOF'
#include <chrono>
#include <cstdio>
using namespace std::chrono;
auto G0 = steady_clock::now();
printf("G0 立刻读 = %lld\n", (long long)G0.time_since_epoch().count());
auto G1 = steady_clock::now();
printf("G1 立刻读 = %lld\n", (long long)G1.time_since_epoch().count());
printf("G0 再读一次 = %lld\n", (long long)G0.time_since_epoch().count());
printf("G1 再读一次 = %lld\n", (long long)G1.time_since_epoch().count());
.q
EOF
