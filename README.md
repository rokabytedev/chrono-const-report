# `const auto` 不会让 `chrono::now()` 出错

> 一次针对「在 macOS 上 `const auto t = chrono::<AnyClock>::now()` 因常量折叠（constant folding）返回错误时间，改成 `auto` 就对了，应该是编译器 bug」这一论断的**实机验证**。
>
> 📄 **完整报告（含全部图表与数据）**：https://chrono-const-report.vercel.app

本仓库包含验证用的全部源码、运行脚本和未经修饰的原始输出。所有数字都是在一台 MacBook Pro 上实测得到的，没有一条来自推断。

---

## 起因

某个技术群里的一段话：

> 在 macbook 上发现一个应该是编译器 bug。
>
> 如果我写 `const auto t = chrono::<AnyClock>::now()`。返回的时间是有问题的。
>
> 如果我把 `const auto` 改成 `auto`，就对了。
>
> 感觉应该是 constant folding 出了问题。花了老子半个小时琢磨为啥测出来的 performance 不对。

这段话包含三个彼此独立、都可以被单独证伪的命题：

| # | 命题 | 检验方式 | 结果 |
|---|------|---------|------|
| **P1** | `const auto` 版本得到的时间是错的 | 行为测量 | ❌ 未复现 |
| **P2** | 改成 `auto` 结果就正确了 | 行为测量 + 代码生成对照 | ❌ 未复现 |
| **P3** | 原因是常量折叠（constant folding） | 语言规则 + 编译器诊断 | ❌ 可直接证伪 |

**裁决：论断不成立。这不是编译器 bug。**

需要说清楚的是：他遇到的「测出来的 performance 不对」大概率是真的。本仓库否认的是**归因**——把它算到 `const` 和常量折叠头上。第「真正的元凶」一节给出了五个能真实造成这种症状、而且在同一台机器上复现出来的原因。

---

## 测试环境

```
# 硬件 / 系统
MacBookPro18,2 · Apple M1 Max · hw.ncpu = 10
macOS 26.5.2 (25F84)

# 编译器 A —— Xcode 26.3 自带
Apple clang version 17.0.0 (clang-1700.6.4.2)
Target: arm64-apple-darwin25.5.0 · target-cpu apple-m1

# 编译器 B —— Command Line Tools 自带（更新）
Apple clang version 21.0.0 (clang-2100.1.1.101)

# 编译器 C —— Homebrew 上游 LLVM，与 Apple 分支无关
Homebrew clang version 20.1.5

# 标准库
_LIBCPP_VERSION = 210106
-isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk  (target-sdk-version 26.5)
```

覆盖的编译配置：`-O0` / `-O1` / `-O2` / `-O3` × `c++17` / `c++20` / `c++23`（共 12 组），
另加 `-Ofast`、`-O3 -flto`、`-O3 -mcpu=native`、`-Ofast -flto -mcpu=native`，
以及一组 `-arch x86_64`（Rosetta）交叉验证。

> **关于「AnyClock」**：本机 libc++ 的 `__cpp_lib_chrono = 201611`，即 Apple 发行的标准库没有开放 C++20 的
> `utc_clock` / `tai_clock` / `gps_clock` / `file_clock`。可用的三个标准时钟
> ——`system_clock`、`steady_clock`、`high_resolution_clock`——全部测了。
> 而且下面证据 1–3 的论证是**结构性**的，不依赖于具体是哪个 clock。

---

## 证据 1 · 编译器吐出来的机器码逐字节相同

写两个除了 `const` 之外完全一样的函数，放进**同一个翻译单元**、用**同一次编译**产出汇编（[`src/test3_asm.cpp`](src/test3_asm.cpp)）：

```cpp
long long elapsed_nonconst() {
    auto t0 = steady_clock::now();
    work();
    auto t1 = steady_clock::now();
    return duration_cast<nanoseconds>(t1 - t0).count();
}

long long elapsed_const() {
    const auto t0 = steady_clock::now();
    work();
    const auto t1 = steady_clock::now();
    return duration_cast<nanoseconds>(t1 - t0).count();
}
```

`clang++ -std=c++20 -O2 -S` 的输出（已去掉 `.cfi` 伪指令和符号名）：

```
elapsed_nonconst                    elapsed_const
────────────────────────────        ────────────────────────────
stp  x20, x19, [sp, #-32]!          stp  x20, x19, [sp, #-32]!
stp  x29, x30, [sp, #16]            stp  x29, x30, [sp, #16]
add  x29, sp, #16                   add  x29, sp, #16
bl   steady_clock::now()            bl   steady_clock::now()
mov  x19, x0                        mov  x19, x0
bl   work()                         bl   work()
bl   steady_clock::now()            bl   steady_clock::now()
sub  x0, x0, x19                    sub  x0, x0, x19
ldp  x29, x30, [sp, #16]            ldp  x29, x30, [sp, #16]
ldp  x20, x19, [sp], #32            ldp  x20, x19, [sp], #32
ret                                 ret
```

```
$ diff a.txt b.txt
# （无输出）
指令数: nonconst = 11    const = 11
md5:    nonconst = 27bd6f884ad1c3990945379907774666
        const    = 27bd6f884ad1c3990945379907774666
```

| 编译器 | 指令数 | 汇编比对 | md5 |
|--------|-------|---------|-----|
| Apple clang 17.0.0 | 11 / 11 | ✅ 完全相同 | `27bd6f88…` |
| Apple clang 21.0.0 | 11 / 11 | ✅ 完全相同 | `27bd6f88…` |
| Homebrew clang 20.1.5 | — | ✅ 完全相同 | — |

**结论**：编译器在代码生成层面对 `const auto` 和 `auto` 没有任何区别对待。既然指令完全一样，就不存在「一个版本算对、另一个版本算错」的物理可能。

---

## 证据 2 · LLVM IR 层面同样相同

汇编相同还可能被质疑成「后端把差异抹平了」。所以再往上看一层：LLVM IR，**在整条优化管线跑完之后、指令选择之前**。常量折叠是一个 IR 层面的变换——如果它真的发生了，这里一定看得见。

```llvm
; elapsed_nonconst 函数体            ; elapsed_const 函数体
%N = tail call i64 @…steady_clock3nowEv()   %N = tail call i64 @…steady_clock3nowEv()
tail call void @_Z4workv()                  tail call void @_Z4workv()
%N = tail call i64 @…steady_clock3nowEv()   %N = tail call i64 @…steady_clock3nowEv()
%N = sub nsw i64 %N, %N                     %N = sub nsw i64 %N, %N
ret i64 %N                                  ret i64 %N
```

```
>>> 函数体 IR 完全相同 (IDENTICAL)
md5: nonconst = 916a606c8c579b13627207aadbd3ab7e
     const    = 916a606c8c579b13627207aadbd3ab7e
```

注意 IR 里**两次 `call now()` 都原样保留着**，一次都没被合并、外提或折叠。Homebrew clang 20.1.5 的对照结果同样是完全相同。

<sub>严谨起见：两个函数的 `define` 行本身确实不同，但差异仅在 mangled 名 `_Z16elapsed_nonconstv` 与 `_Z13elapsed_constv`（长度前缀 16 与 13）。上面比对的是函数体，md5 取自函数体。</sub>

---

## 证据 3 · 常量折叠在这里物理上不可能

P3 是三个命题里最容易证伪的一个，而且它的证伪**不依赖于任何测量**。

### 常量折叠的前提是「常量表达式」

编译器要折叠一个表达式，前提是能在编译期求值，也就是它必须是 constant expression。那就强制要求它是，看编译器怎么说（[`src/test5_constexpr.cpp`](src/test5_constexpr.cpp)）：

```
$ clang++ -std=c++23 -O2 test5_constexpr.cpp
error: constexpr variable 't' must be initialized by a constant expression
    3 | constexpr auto t = steady_clock::now();
      |                ^   ~~~~~~~~~~~~~~~~~~~
note: non-constexpr function 'now' cannot be used in a constant expression
/…/c++/v1/__chrono/steady_clock.h:34:21: note: declared here
   34 |   static time_point now() _NOEXCEPT;
```

标准库里 `now()` 的声明就摆在那里：`static time_point now() _NOEXCEPT;`——**没有 `constexpr`**。编译器根本没有权限对它求值。（Apple clang 17 与 21 输出一致。）

### 它甚至不是编译器能看穿的函数

```
$ clang++ -std=c++20 -O2 -c test3_asm.cpp -o test3.o
$ nm test3.o | grep -i now | c++filt

U  std::__1::chrono::steady_clock::now()
^ U = undefined，一个不透明的外部调用
```

实现体在 `libc++.dylib` 里，编译单个 TU 时编译器连它的函数体都看不到。而且它**没有**被标注 `__attribute__((const))` 或 `((pure))`——这一点决定性地关闭了另一条路：编译器不被允许假设两次 `now()` 返回同样的值，因此连公共子表达式消除（CSE）都做不了，更别说折叠成编译期常量。

### 顺带澄清：`const` 在这里不给优化器任何新信息

- 对**局部变量**而言，优化器手里有整个函数体，本来就完整知道这个变量有没有被改过。加不加 `const` 不会给它额外的假设权限。
- `const` 只是「承诺你不通过这个名字去修改它」，**不是**「这个值在编译期已知」。后者是 `constexpr` / `constinit` 的活。
- `auto` 推导会丢弃顶层 `const`：两种写法里 `t` 的推导类型同为 `steady_clock::time_point`，前者只是多了个顶层 cv 限定符。这也是 IR 会一模一样的原因。

---

## 证据 4 · 行为层面，816 对配对测量零差异

### 方法：每次测量都配一个独立参照物

chrono 的读数不能自己证明自己。所以每一段被测区间外面再套一层 `clock_gettime(CLOCK_MONOTONIC)`——一个完全不经过 `<chrono>` 的独立时间源。如果 chrono 在撒谎，两者必然对不上。

| 配置 | clock | auto | 参照 | const auto | 参照 |
|------|-------|-----:|-----:|-----------:|-----:|
| -O2 c++17 | steady_clock | 11.0062 | **11.0070** | 10.4513 | **10.4520** |
| -O2 c++17 | high_resolution | 10.7333 | **10.7340** | 10.8817 | **10.8820** |
| -O2 c++20 | system_clock | 10.5890 | **10.5890** | 10.3780 | **10.3780** |
| -O2 c++20 | steady_clock | 10.5916 | **10.5930** | 10.5471 | **10.5470** |
| -O3 -flto | high_resolution | 11.9908 | **11.9910** | 10.8184 | **10.8190** |
| x86_64 (Rosetta) | steady_clock | 26.1059 | **26.1090** | 26.2531 | **26.2550** |

单位 ms。chrono 读数与独立参照物在小数点后三位吻合——两种写法都是。

### 统计学对照：交替采样 200 轮 × 3 个 clock

单次测量是有噪声的，拿单点说事对谁都不公平。所以做配对交替采样（奇偶轮换先后顺序以抵消漂移），每个 clock 各 200 对（[`src/test12_stats.cpp`](src/test12_stats.cpp)）：

```
system_clock     auto : p50=10.7450  p25=10.6540  p75=10.8710  min=10.5390
                 const: p50=10.7680  p25=10.6540  p75=10.8950  min=10.5420
                 中位数差异 +0.214%    最小值差异 +0.028%

steady_clock     auto : p50=10.7142  p25=10.6246  p75=10.8625  min=10.5405
                 const: p50=10.7344  p25=10.6409  p75=10.8829  min=10.5781
                 中位数差异 +0.189%    最小值差异 +0.357%

high_resolution  auto : p50=10.8168  p25=10.7101  p75=10.9391  min=10.5667
                 const: p50=10.8240  p25=10.6992  p75=10.9405  min=10.5751
                 中位数差异 +0.067%    最小值差异 +0.080%
```

另有一组用完全已知的时长做标尺（`sleep_for(100ms)`），12 组编译配置 × 3 clock × 3 轮，两种写法全部落在 100–110 ms 区间。还测了最原始的一层：交错采样 `const` / `auto` 五个时间点检查原始 tick 值的单调性，全部编译配置下 **100% 单调递增**。

**结论**：216 对（矩阵测量）+ 600 对（统计测量）配对样本，跨 4 个优化级别、3 个语言标准、两种 CPU 架构、三种 clock，两种写法的差异全部落在测量噪声内（中位数差异 ≤ 0.214%）。

---

## 证据 5 · 所有 `const` 相关写法变体

为了排除「也许你写的 const 和我写的 const 不是同一个写法」（[`src/test9_variants.cpp`](src/test9_variants.cpp)）：

| 写法 | r1 | r2 | r3 | r4 | r5 |
|------|---:|---:|---:|---:|---:|
| `auto t = now()` | 10.3658 | 10.5269 | 10.5455 | 10.3835 | 10.6267 |
| `const auto t = now()` | 10.6197 | 10.4242 | 10.7830 | 10.7027 | 10.3456 |
| `auto const t = now()` | 10.5848 | 10.6844 | 10.8179 | 10.4926 | 10.5246 |
| `const auto& t = now()` | 10.3794 | 10.2852 | 10.3049 | 10.2720 | 10.3208 |
| `auto&& t = now()` | 10.3050 | 10.2592 | 10.2954 | 10.3336 | 10.3061 |
| `volatile auto t = …` | 10.2826 | 10.3161 | 10.2733 | 10.6237 | 10.2979 |

单位 ms，Apple clang 17 / `-O2`。同样的表在 Apple clang 21 和 Homebrew clang 20 上重跑，结论一致。

---

## 那半小时到底撞见了什么

「测出来的 performance 不对」是个真问题，只是原因不在 `const` 上。下面五个都是在**同一台机器上真实复现出来**的、能造成这种症状的原因，按可能性排序。

### A · 死代码消除：被测代码整段被删掉

如果被测函数的返回值没人用，`-O2` 会把它整个删掉（[`src/test4_dce.cpp`](src/test4_dce.cpp)）：

```
-O2，500 万次 sin 调用：
auto       + 丢弃返回值 :     0.0000 ms   <-- 循环被整段删除
const auto + 丢弃返回值 :     0.0000 ms   <-- 同样被删除
auto       + volatile   :    27.7323 ms
const auto + volatile   :    28.0530 ms
```

**注意两种写法都是 0。** 但这里有个非常容易骗到人的陷阱：改代码时哪怕只是把 `const auto` 改成 `auto`，如果顺手动了别的东西——多打了一行 print、多存了一个中间变量、把结果传给了某个函数——就可能刚好挡住了 DCE。于是现象变成「改掉 const 就对了」，而真正起作用的是那个顺手的改动。这是最典型的假因果。

### B · 冷启动：第一次测量普遍高 2.5–3.5 倍

刚编译出来的二进制，进程内的*第一次*测量会明显偏高（页错误、dyld 惰性绑定、缓存冷）。在 12 组编译配置里 **12/12 全部命中**：

```
每组配置里的第一次测量（ms）：
34.7100  38.5490  34.6590  31.9880  33.2860  42.8050
29.3850  31.0760  38.4640  29.7700  28.8190  31.4600

同组稳态区间：10.3 – 16.1     倍率：2.5x – 3.5x
```

关键在于：**独立的 `clock_gettime` 参照物也同步偏高**，说明这是真的慢了，不是 chrono 测错了。只要 A/B 两个版本在程序里有先后顺序，先跑的那个就会背上这笔冷启动成本——而「先跑的那个」往往就是你先写的那个版本。加上 warmup 之后，两者差异回到 0.5% 以内。

### C · `static const auto`：唯一一个「加 const 就真的错」的写法

这是整轮实验里找到的、唯一能同时解释「加 const 出错」和「去掉 const 就好」的写法。`static` 局部变量只在**第一次**执行到那一行时初始化：

```cpp
static const auto t0 = Clock::now();   // 只在首次调用时采样！
work(n);
static const auto t1 = Clock::now();   // 同上
```

```
同一个函数连调 3 次：
  第 1 次调用:    10.5903 ms
  第 2 次调用:    10.5903 ms   <-- 时间点没有重新采样
  第 3 次调用:    10.5903 ms   <-- 永远返回第一次的结果
```

如果原始代码是这个形状，那「改掉 const 就好了」是**真的**——因为 `static auto` 同样会有这个问题，但很多人在删 `const` 的时候会把 `static` 一起删掉。原因是 C++ 的 `static` 存储期规则，不是编译器 bug，也和常量折叠无关。

### D · 命名空间作用域的 `const`

这是 C++ 里 `const` 唯一真正改变语义的地方：它给变量**内部链接**——放进头文件被多个 TU 包含时，每个 TU 各持一份自己的拷贝；而去掉 `const` 会变成重复定义的链接错误，逼你改写法。实测数值本身正确（都是程序启动时刻，不是 main 开始时刻），但多 TU 场景下语义会变（[`src/test10_namespace.cpp`](src/test10_namespace.cpp)）。

### E · 选错了时钟

| clock | period | is_steady | 身份 |
|-------|--------|-----------|------|
| `system_clock` | 1 µs | ❌ 0（会跳变） | 墙上时间 |
| `steady_clock` | 1 ns | ✅ 1 | 单调时钟 |
| `high_resolution_clock` | 1 ns | ✅ 1 | **= steady_clock** |

`system_clock` 的 `is_steady = 0`——NTP 校时会让它跳变甚至倒退，不该用来做 benchmark。本机实测确认 `high_resolution_clock` 就是 `steady_clock`（不是 `system_clock`），所以在 macOS 上用它计时没问题。

---

## 10 秒自证

证伪常量折叠假说最快的一条，不需要跑任何 benchmark：

```bash
echo '#include <chrono>
constexpr auto t = std::chrono::steady_clock::now();' | clang++ -std=c++23 -x c++ -c - -o /dev/null
```

```
error: constexpr variable 't' must be initialized by a constant expression
note: non-constexpr function 'now' cannot be used in a constant expression
```

---

## 复现全部实验

```bash
git clone https://github.com/rokabytedev/chrono-const-report.git
cd chrono-const-report/src
bash run.sh      # 全矩阵：4 个优化级别 × 3 个语言标准
bash run2.sh     # constexpr 证伪、汇编 diff、-Ofast/-flto/native、GCC 对照
bash run3.sh     # IR 对照、符号表、写法变体、命名空间、x86_64、多编译器
bash run4.sh     # IR 归一化对照、Command Line Tools clang、Homebrew clang
```

### 文件清单

| 文件 | 作用 |
|------|------|
| [`src/test1_value.cpp`](src/test1_value.cpp) | 原始 tick 数值与单调性 |
| [`src/test2_measure.cpp`](src/test2_measure.cpp) | 带 `clock_gettime` 独立参照物的测量 |
| [`src/test3_asm.cpp`](src/test3_asm.cpp) | 汇编 / LLVM IR 对照用的最小样本 |
| [`src/test4_dce.cpp`](src/test4_dce.cpp) | 死代码消除陷阱 |
| [`src/test5_constexpr.cpp`](src/test5_constexpr.cpp) | 常量折叠证伪（预期编译失败） |
| [`src/test8_order.cpp`](src/test8_order.cpp) | 执行顺序调换 / 冷启动 |
| [`src/test9_variants.cpp`](src/test9_variants.cpp) | 六种写法变体 + `static const auto` 陷阱 |
| [`src/test10_namespace.cpp`](src/test10_namespace.cpp) | 命名空间作用域 const 与内部链接 |
| [`src/test11_allclocks.cpp`](src/test11_allclocks.cpp) | 全部标准 clock 覆盖 |
| [`src/test12_stats.cpp`](src/test12_stats.cpp) | 交替采样 200 轮统计对照 |
| [`raw/full-matrix.txt`](raw/full-matrix.txt) | 12 组编译配置的完整原始输出 |
| [`raw/variants-and-toolchains.txt`](raw/variants-and-toolchains.txt) | 变体与多工具链对照的原始输出 |
| [`index.html`](index.html) | 报告页面本体（静态页，无构建步骤） |

---

## 这份报告的边界

诚实说明局限，免得被当成过度声张：

1. **没有跑到原始代码。** 复现的是论断所描述的形状，不是那段代码本身。如果原始代码里真的存在 bug，本仓库已独立证明它的原因不会是常量折叠（证据 3），也不会是 `const` 改变了代码生成（证据 1、2）——但具体是什么，需要看到代码才能定位。上面「真正的元凶」一节列了五个方向，其中 C（`static const auto`）能同时解释「加 const 出错」和「去掉 const 就好」这两个现象。
2. **x86_64 走的是 Rosetta，不是原生 Intel 硬件。** 这是真实的覆盖缺口。不过证据 3 的证伪与架构无关。
3. **C++20 的 `utc_clock` / `tai_clock` / `gps_clock` / `file_clock` 没测到**，因为这台机器上的 Apple libc++ 没开放它们（`__cpp_lib_chrono = 201611`）。它们都建立在 `system_clock::now()` 之上，同样不是 `constexpr`。

欢迎提 issue 反驳。如果能提供可复现的代码片段，我会在同一台机器上跑一遍并更新这份报告。

---

## License

MIT
