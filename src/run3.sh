#!/bin/bash
set -u
cd "$(dirname "$0")"
CXX=${CXX:-clang++}

echo "############ 环境细节 ############"
$CXX --version
echo "--- 使用的 SDK ---"
$CXX -std=c++20 -E -v -x c++ /dev/null 2>&1 | grep -E "^ /|SDK|-isysroot" | head -8
echo "--- libc++ 版本 ---"
echo '#include <__config>
#include <cstdio>
int main(){ printf("_LIBCPP_VERSION = %d\n", _LIBCPP_VERSION); }' > /tmp/lcv.cpp
$CXX -std=c++20 /tmp/lcv.cpp -o /tmp/lcv && /tmp/lcv
echo

echo "############ 实验 11：LLVM IR 层面对照 (-O2) ############"
$CXX -std=c++20 -O2 -S -emit-llvm -o test3.ll test3_asm.cpp
awk '/^define .*elapsed_nonconstv/,/^}/' test3.ll | sed 's/%[0-9]*/%N/g; s/elapsed_nonconstv/FN/' > ir_a.txt
awk '/^define .*elapsed_constv/,/^}/'    test3.ll | sed 's/%[0-9]*/%N/g; s/elapsed_constv/FN/'    > ir_b.txt
echo "非 const 版 IR:"; cat ir_a.txt
echo "const 版 IR:"; cat ir_b.txt
if diff -q ir_a.txt ir_b.txt >/dev/null; then echo ">>> IR 完全相同 (IDENTICAL)"; else echo ">>> IR 有差异 !!!"; diff ir_a.txt ir_b.txt; fi
echo

echo "############ 实验 12：now() 在二进制里是不是外部符号 ############"
$CXX -std=c++20 -O2 -c test3_asm.cpp -o test3.o
echo "--- test3.o 中与 now 相关的符号 (U = undefined，即编译器看不见的外部调用) ---"
nm test3.o | grep -i "now" | c++filt
echo

echo "############ 实验 9：写法变体 ############"
$CXX -std=c++20 -O2 test9_variants.cpp -o t9 && ./t9
echo

echo "############ 实验 10：命名空间作用域 ############"
$CXX -std=c++20 -O2 test10_namespace.cpp -o t10 && ./t10
echo

echo "############ 实验 13：x86_64 (Rosetta) 交叉验证 ############"
if $CXX -std=c++20 -O2 -arch x86_64 test2_measure.cpp -o t2x 2>/dev/null; then
  file t2x
  ./t2x 2>&1 | grep -A4 "2b" | head -6 || echo "（无法在本机执行 x86_64，可能未装 Rosetta）"
else
  echo "无法为 x86_64 编译（缺少该架构的 SDK / 工具链）"
fi
echo

echo "############ 实验 14：另一套 clang（Command Line Tools）对照 ############"
for ALT in /usr/bin/clang++ /Library/Developer/CommandLineTools/usr/bin/clang++ /opt/homebrew/opt/llvm/bin/clang++; do
  if [ -x "$ALT" ]; then
    echo "--- $ALT ---"
    "$ALT" --version | head -1
    "$ALT" -std=c++20 -O2 -S -o alt.s test3_asm.cpp 2>/dev/null && {
      awk '/elapsed_nonconstv:/,/End function/' alt.s | grep -vE '^\s*(;|\.|__Z)' > aa.txt
      awk '/elapsed_constv:/,/End function/'    alt.s | grep -vE '^\s*(;|\.|__Z)' > bb.txt
      if diff -q aa.txt bb.txt >/dev/null; then echo "    汇编对照: 完全相同 (IDENTICAL)"; else echo "    汇编对照: 有差异!"; diff aa.txt bb.txt; fi
    }
    "$ALT" -std=c++20 -O2 test9_variants.cpp -o t9alt 2>/dev/null && ./t9alt | head -9
  fi
done
