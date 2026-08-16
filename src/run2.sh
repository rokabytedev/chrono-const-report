#!/bin/bash
set -u
cd "$(dirname "$0")"
CXX=${CXX:-clang++}

echo "############ 实验 5：now() 是否 constexpr（能否常量折叠）############"
$CXX -std=c++23 -O2 test5_constexpr.cpp -o t5 2>&1 | head -20
echo "编译退出码: ${PIPESTATUS[0]}"
echo

echo "############ 实验 3b：两个函数体的汇编逐字节 diff ############"
$CXX -std=c++20 -O2 -S -o test3.s test3_asm.cpp
# 抽出两个函数体，去掉符号名和标签，做 diff
awk '/^__Z16elapsed_nonconstv:/,/End function/' test3.s | grep -vE '^\s*(;|\.|__Z)' > a.txt
awk '/^__Z13elapsed_constv:/,/End function/'    test3.s | grep -vE '^\s*(;|\.|__Z)' > b.txt
echo "非 const 版指令数: $(wc -l < a.txt)   const 版指令数: $(wc -l < b.txt)"
if diff -q a.txt b.txt >/dev/null; then
  echo "结果: 指令序列完全相同 (IDENTICAL)"
else
  echo "结果: 有差异 !!!"
  diff a.txt b.txt
fi
echo
echo "md5: nonconst=$(md5 -q a.txt)  const=$(md5 -q b.txt)"
echo

echo "############ 实验 6：-Ofast / -flto / -march=native 下再测 ############"
for FLAGS in "-Ofast" "-O3 -flto" "-O3 -mcpu=native" "-Ofast -flto -mcpu=native"; do
  echo "--- clang++ -std=c++20 $FLAGS ---"
  $CXX -std=c++20 $FLAGS test2_measure.cpp -o t2f 2>&1 && ./t2f | grep -A4 "2b"
  echo
done

echo "############ 实验 7：g++ (Homebrew GCC) 对照，如果装了 ############"
if command -v g++-15 >/dev/null; then G=g++-15;
elif command -v g++-14 >/dev/null; then G=g++-14;
else G=""; fi
if [ -n "$G" ]; then
  $G --version | head -1
  $G -std=c++20 -O2 test2_measure.cpp -o t2g && ./t2g | grep -A4 "2b"
else
  echo "未安装 Homebrew GCC，跳过（/usr/bin/g++ 只是 clang 的马甲）"
fi
