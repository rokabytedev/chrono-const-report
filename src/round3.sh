#!/bin/bash
# 第三轮：排除混淆项。
#  (1) 顶层变量读成 0 / 每次读不一样，是 chrono 特有，还是所有顶层变量都这样？
#  (2) 是不是 cling 的 stdlib ABI 不匹配造成的？
export PATH=/opt/conda/bin:$PATH
Q() { cling 2>&1 | grep -vE "Possible C\+\+ standard|Extraction of runtime|^\*+|^\| |^$|Type C\+\+|introduction and demos|^\[cling\]"; }

echo "########## H：不涉及任何标准库类型的顶层变量（纯 POD）##########"
Q <<'EOF'
#include <cstdio>
long long counter = 0;
long long bump(){ return ++counter; }
auto H0 = bump();
auto H1 = bump();
printf("H0=%lld H1=%lld  (期望 1 和 2)\n", (long long)H0, (long long)H1);
printf("H0 再读=%lld H1 再读=%lld  (应与上行相同)\n", (long long)H0, (long long)H1);
printf("counter 实际被调用了 %lld 次\n", counter);
.q
EOF

echo
echo "########## I：顶层 const POD ##########"
Q <<'EOF'
#include <cstdio>
long long counter2 = 0;
long long bump2(){ return ++counter2; }
const auto I0 = bump2();
const auto I1 = bump2();
printf("I0=%lld I1=%lld  (期望 1 和 2)\n", (long long)I0, (long long)I1);
printf("I0 再读=%lld I1 再读=%lld\n", (long long)I0, (long long)I1);
printf("counter2 实际被调用了 %lld 次\n", counter2);
.q
EOF

echo
echo "########## J：顶层 int64（直接存 tick，绕开 time_point 这个类类型）##########"
Q <<'EOF'
#include <chrono>
#include <cstdio>
using namespace std::chrono;
long long J0 = steady_clock::now().time_since_epoch().count();
long long J1 = steady_clock::now().time_since_epoch().count();
printf("J0=%lld J1=%lld  diff=%lld\n", J0, J1, J1-J0);
printf("J0 再读=%lld J1 再读=%lld\n", J0, J1);
.q
EOF

echo
echo "########## K：ABI 混淆项 —— 当前 libstdc++ 版本情况 ##########"
cling --version
echo '#include <cstdio>' | cling 2>&1 | grep -A3 "ABICompat" | head -6
echo "--- conda 里的 libstdcxx ---"
micromamba list 2>/dev/null | grep -iE "libstdcxx|libgcc|gcc" | head
echo "--- 运行时实际加载的 libstdc++ ---"
ls -la /opt/conda/lib/libstdc++.so.6 2>/dev/null
strings /opt/conda/lib/libstdc++.so.6 2>/dev/null | grep -oE "GLIBCXX_3\.4\.[0-9]+" | sort -V -u | tail -3
echo "--- 系统 libstdc++ ---"
ls -la /usr/lib/x86_64-linux-gnu/libstdc++.so.6 2>/dev/null
