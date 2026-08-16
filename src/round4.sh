#!/bin/bash
# 第四轮：排掉 ABI 混淆项后，确认「顶层 const vs 非 const 走不同路径且其一是坏的」。
export PATH=/opt/conda/bin:$PATH
Q() { cling 2>&1 | grep -vE "Possible C\+\+ standard|Extraction of runtime|^\*+|^\| |^$|Type C\+\+|introduction and demos|^\[cling\]|CheckABICompat"; }

PROBE='#include <cstdio>
long long n = 0;
long long bump(){ return ++n; }
auto  X0 = bump();
auto  X1 = bump();
auto  X2 = bump();
printf("非const: X0=%lld X1=%lld X2=%lld   (期望 1 2 3)  bump 实际调用 %lld 次\n", (long long)X0,(long long)X1,(long long)X2, n);
long long m = 0;
long long bump2(){ return ++m; }
const auto Y0 = bump2();
const auto Y1 = bump2();
const auto Y2 = bump2();
printf("const  : Y0=%lld Y1=%lld Y2=%lld   (期望 1 2 3)  bump2 实际调用 %lld 次\n", (long long)Y0,(long long)Y1,(long long)Y2, m);
.q'

echo "########## L：默认环境（conda libstdc++ 6.0.35，ABI 不匹配）##########"
echo "$PROBE" | Q

echo
echo "########## M：强制使用系统 libstdc++ 6.0.33（消除 ABI 警告）##########"
echo "--- 先确认警告是否消失 ---"
LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH \
  bash -c 'echo "int q=1;" | cling 2>&1 | grep -c "CheckABICompatibility"' \
  && echo "(0 = 警告已消除)"
echo "--- 同一个探针重跑 ---"
echo "$PROBE" | LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH Q

echo
echo "########## N：重复 5 次，确认结果稳定不是偶然 ##########"
for i in 1 2 3 4 5; do
  printf "第 %d 次: " $i
  echo "$PROBE" | Q | grep -E "非const|const  " | tr '\n' '|'
  echo
done
