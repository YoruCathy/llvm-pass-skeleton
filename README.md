# LLVM Pass: Floating-Point Logging, Divide-by-Zero Detection, and Small Integer Optimization

This project extends the LLVM `skeleton` pass into a multi-purpose analysis and optimization pass.  
It instruments floating-point divisions, detects potential divide-by-zero operations, and implements a **small-integer interning optimization** inspired by Python’s integer cache.  
A benchmark suite and shell harness are included for performance evaluation.

---

## Features

### 1. Floating-Point Division Logging
- Detects all `fdiv` instructions in the LLVM IR.
- Inserts calls to a runtime logger (`log_fdiv`) that prints a message when a floating-point division occurs.

### 2. Divide-by-Zero Detection
- Performs **compile-time analysis** to warn about constant zero divisors.
- Injects **runtime checks** (`log_divzero_check`) before each floating-point or integer division to catch dynamic zero divisors safely.

### 3. Small-Integer Interning Optimization
- Rewrites calls to `box_i64(C)` where `C ∈ [-5, 256]` into `get_small_int(C)` to reuse preallocated integer singletons.
- This reduces memory allocations and improves performance in workloads with many small integers.

---

## Evaluation and Benchmarks

### Functional Tests
- `example_fdivd.c` and `example_divzero.c`: hand-written programs to verify correct instrumentation and runtime behavior.

### Optimization Benchmarks
- `test_smallint_bench.c`: synthetic benchmark testing small-integer interning across three workloads:
  - **const_range** – all integers within [–5, 256]
  - **mixed** – a mix of in-range and out-of-range integers
  - **large_only** – only large (non-interned) integers

### Results Summary

| Case        | Baseline Allocations | Optimized Allocations | Speedup |
|--------------|----------------------|------------------------|----------|
| const_range  | 150M                 | 0                      | ~6×      |
| mixed        | 100M                 | 100M                   | ≈ same   |
| large_only   | 100M                 | 100M                   | ≈ same   |

---

## Repository Structure

```
.
├── skeleton/                  # LLVM pass source (Skeleton.cpp, CMakeLists.txt)
├── logger.c                   # Runtime logger for fdiv/div-by-zero
├── smallint.c                 # Runtime for box_i64 / get_small_int
├── test_smallint.c            # Functional test for small-int optimization
├── test_smallint_bench.c      # Benchmark harness
├── bench.sh                   # Automated benchmark runner
├── example_fdivd.c            # Floating-point division test
├── example_divzero.c          # Divide-by-zero test
└── build/                     # CMake build directory
```

---

## Build Instructions

### 1. Configure and build the pass
```bash
cmake -S . -B build
cmake --build build
```

### 2. Run on test input
```bash
CLANG="$(brew --prefix llvm)/bin/clang"
OPT="$(brew --prefix llvm)/bin/opt"

# Compile to LLVM IR
$CLANG -O0 -S -emit-llvm example_divzero.c -o example.ll

# Run the pass
$OPT -load-pass-plugin ./build/skeleton/SkeletonPass.dylib      -passes=skeleton-pass example.ll -S -o instrumented.ll
```

### 3. Build and run the instrumented code
```bash
"$(brew --prefix llvm)/bin/llc" -filetype=obj instrumented.ll -o instrumented.o
cc instrumented.o logger.o -o a.out
./a.out
```

### 4. Run the benchmarks
```bash
chmod +x bench.sh
./bench.sh
```





