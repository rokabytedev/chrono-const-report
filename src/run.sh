#!/bin/bash
# 在 Mac 上跑完整对照实验
set -u
cd "$(dirname "$0")"
CXX=${CXX:-clang++}

echo "############ 工具链 ############"
$CXX --version
echo

for OPT in -O0 -O1 -O2 -O3; do
  echo "################################################################"
  echo "############ 优化级别 $OPT ############"
  echo "################################################################"
  for STD in c++17 c++20 c++23; do
    echo "=================== -std=$STD $OPT ==================="
    $CXX -std=$STD $OPT test1_value.cpp -o t1 2>&1 && ./t1
    echo
    $CXX -std=$STD $OPT test2_measure.cpp -o t2 2>&1 && ./t2
    echo
    $CXX -std=$STD $OPT test4_dce.cpp -o t4 2>&1 && ./t4
    echo
  done
done

echo "################################################################"
echo "############ 反汇编对照 (-O2) ############"
echo "################################################################"
$CXX -std=c++20 -O2 -S -o test3.s test3_asm.cpp
echo "--- 完整汇编 ---"
cat test3.s
