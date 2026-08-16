#!/bin/bash
CL=/opt/conda/envs/cl2/bin/cling
export PATH=/opt/conda/envs/cl2/bin:$PATH
echo "=== cling 版本 ==="; $CL --version 2>&1 | head -1
echo "=== ABI 警告条数（0 = 干净）==="
echo 'int q=1;' | $CL 2>&1 | grep -c "CheckABICompatibility"
echo "=== 冒烟：函数定义 + include 是否可用 ==="
printf '#include <cstdio>\nlong long z(){ return 7; }\nprintf("smoke=%%lld\\n",(long long)z());\n.q\n' | $CL 2>&1 | grep -E "smoke=|error" | head -3
echo
Q() { $CL 2>&1 | grep -vE "Possible C\+\+ standard|Extraction of runtime|^\*+|^\| |^$|Type C\+\+|introduction and demos|^\[cling\]|CheckABICompat"; }
PROBE='#include <cstdio>
long long n = 0;
long long bump(){ return ++n; }
auto  X0 = bump();
auto  X1 = bump();
auto  X2 = bump();
printf("NONCONST: X0=%lld X1=%lld X2=%lld  expect 1 2 3 | bump called %lld times\n", (long long)X0,(long long)X1,(long long)X2, n);
long long m = 0;
long long bump2(){ return ++m; }
const auto Y0 = bump2();
const auto Y1 = bump2();
const auto Y2 = bump2();
printf("CONST   : Y0=%lld Y1=%lld Y2=%lld  expect 1 2 3 | bump2 called %lld times\n", (long long)Y0,(long long)Y1,(long long)Y2, m);
.q'
echo "=== 探针 · 重复 3 次 ==="
for i in 1 2 3; do printf "第 %d 次  " $i; echo "$PROBE" | Q | grep -E "NONCONST|CONST"; done
echo
echo "=== chrono 顶层 ==="
Q <<'EOF'
#include <chrono>
#include <cstdio>
using namespace std::chrono;
auto a0 = steady_clock::now();
auto a1 = steady_clock::now();
printf("AUTO : a0=%lld a1=%lld dur=%lld ns\n",(long long)a0.time_since_epoch().count(),(long long)a1.time_since_epoch().count(),(long long)(a1-a0).count());
const auto c0 = steady_clock::now();
const auto c1 = steady_clock::now();
printf("CONST: c0=%lld c1=%lld dur=%lld ns\n",(long long)c0.time_since_epoch().count(),(long long)c1.time_since_epoch().count(),(long long)(c1-c0).count());
.q
EOF
echo
echo "=== 对照：函数体内应正常 ==="
Q <<'EOF'
#include <chrono>
#include <cstdio>
#include <cmath>
using namespace std::chrono;
double sink=0;
void work(int k){ double s=0; for(int i=1;i<=k;++i) s+=std::sin((double)i)/i; sink=s; }
long long fa(){ auto t0=steady_clock::now(); work(2000000); auto t1=steady_clock::now(); return duration_cast<nanoseconds>(t1-t0).count(); }
long long fc(){ const auto t0=steady_clock::now(); work(2000000); const auto t1=steady_clock::now(); return duration_cast<nanoseconds>(t1-t0).count(); }
fa();
printf("fn auto =%lld ns\n", fa());
printf("fn const=%lld ns\n", fc());
.q
EOF
