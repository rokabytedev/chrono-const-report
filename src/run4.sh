#!/bin/bash
set -u
cd "$(dirname "$0")"
CXX=${CXX:-clang++}

echo "############ 实验 11 修正：IR 对照（把符号名整体归一化）############"
$CXX -std=c++20 -O2 -S -emit-llvm -o test3.ll test3_asm.cpp
# 只保留函数体（去掉 define 那一行的函数名），并把 SSA 编号归一化
awk '/^define .*elapsed_nonconstv/,/^}/' test3.ll | tail -n +2 | sed 's/%[0-9][0-9]*/%N/g' > ir_a.txt
awk '/^define .*elapsed_constv/,/^}/'    test3.ll | tail -n +2 | sed 's/%[0-9][0-9]*/%N/g' > ir_b.txt
echo "--- 非 const 版函数体 ---"; cat ir_a.txt
echo "--- const 版函数体 ---";   cat ir_b.txt
if diff -q ir_a.txt ir_b.txt >/dev/null; then
  echo ">>> 函数体 IR 完全相同 (IDENTICAL)"
else
  echo ">>> 有差异:"; diff ir_a.txt ir_b.txt
fi
echo "md5: nonconst=$(md5 -q ir_a.txt)  const=$(md5 -q ir_b.txt)"
echo "（说明：define 行本身只差 mangled 名 _Z16elapsed_nonconstv / _Z13elapsed_constv，长度前缀 16 vs 13）"
echo

echo "############ 实验 14b：Command Line Tools clang 21 单独排查 ############"
CLT=/Library/Developer/CommandLineTools/usr/bin/clang++
$CLT --version | head -1
echo "--- 直接编译，显示所有错误 ---"
$CLT -std=c++20 -O2 -S -o clt.s test3_asm.cpp 2>&1 | head -20
echo "编译退出码: $?"
if [ -f clt.s ]; then
  awk '/elapsed_nonconstv:/,/End function/' clt.s | grep -vE '^\s*(;|\.|__Z|_Z)' > ca.txt
  awk '/elapsed_constv:/,/End function/'    clt.s | grep -vE '^\s*(;|\.|__Z|_Z)' > cb.txt
  echo "指令数: nonconst=$(wc -l < ca.txt) const=$(wc -l < cb.txt)"
  if diff -q ca.txt cb.txt >/dev/null; then echo ">>> 汇编完全相同 (IDENTICAL)"; else echo ">>> 有差异:"; diff ca.txt cb.txt; fi
fi
echo "--- clang 21 跑实验 9 ---"
$CLT -std=c++20 -O2 test9_variants.cpp -o t9clt 2>&1 | head -10 && ./t9clt
echo
echo "--- clang 21 跑 constexpr 折叠测试 ---"
$CLT -std=c++23 -O2 test5_constexpr.cpp -o t5clt 2>&1 | head -8
echo

echo "############ 实验 15：Homebrew clang 20 的 IR 对照 ############"
BREW=/opt/homebrew/opt/llvm/bin/clang++
if [ -x "$BREW" ]; then
  $BREW --version | head -1
  $BREW -std=c++20 -O2 -S -emit-llvm -o brew.ll test3_asm.cpp 2>/dev/null
  awk '/^define .*elapsed_nonconstv/,/^}/' brew.ll | tail -n +2 | sed 's/%[0-9][0-9]*/%N/g' > ba.txt
  awk '/^define .*elapsed_constv/,/^}/'    brew.ll | tail -n +2 | sed 's/%[0-9][0-9]*/%N/g' > bb2.txt
  if diff -q ba.txt bb2.txt >/dev/null; then echo ">>> 函数体 IR 完全相同 (IDENTICAL)"; else echo ">>> 有差异:"; diff ba.txt bb2.txt; fi
  cat ba.txt
fi
echo

echo "############ 实验 16：steady_clock::now() 在 macOS 上到底调什么 ############"
cat > /tmp/whatnow.cpp <<'EOF'
#include <chrono>
long long f() { return std::chrono::steady_clock::now().time_since_epoch().count(); }
EOF
$CXX -std=c++20 -O2 -c /tmp/whatnow.cpp -o /tmp/whatnow.o
echo "--- 未定义符号（编译器无法看穿的调用）---"
nm -u /tmp/whatnow.o | c++filt
