#!/usr/bin/env bash
# Benchmark small-int interning: baseline vs optimized
# Works on macOS (/usr/bin/time -l). If GNU time (gtime) is installed, uses it.

set -euo pipefail

# ---------- Knobs ----------
TRIALS=5
ITERS_CONST=10000000     # make each run ~1–3s on M1/M2; adjust if needed
ITERS_MIXED=20000000
ITERS_LARGE=20000000

# Paths
BREW_LLVM_PREFIX="$(brew --prefix llvm)"
CLANG="$BREW_LLVM_PREFIX/bin/clang"
OPT="$BREW_LLVM_PREFIX/bin/opt"
LLC="$BREW_LLVM_PREFIX/bin/llc"

PLUGIN="./build/skeleton/SkeletonPass.dylib"
SRC_BENCH="test_smallint_bench.c"
IR_BENCH="test_smallint_bench.ll"
IR_OPT="bench_instrumented.ll"

SMALLINT_O="smallint.o"
BASE_O="base.o"
OPT_O="opt.o"
BASE_BIN="base.out"
OPT_BIN="opt.out"

# ---------- Timing helpers ----------
# Prefer GNU time if available; fall back to macOS /usr/bin/time -l parsing
if command -v gtime >/dev/null 2>&1; then
  TIME_BIN="$(command -v gtime)"
  TIME_FMT="real=%e user=%U sys=%S"
  run_time() { "$TIME_BIN" -f "$TIME_FMT" "$@" 2>&1 >/dev/null; }
  parse_time() {
    local s="$1"
    local real user sys
    real=$(echo "$s" | awk -F'[= ]' '/real=/{print $2}')
    user=$(echo "$s" | awk -F'[= ]' '/user=/{print $2}')
    sys=$(echo "$s"  | awk -F'[= ]' '/sys=/{print $2}')
    printf "%s %s %s\n" "$real" "$user" "$sys"
  }
else
  TIME_BIN="/usr/bin/time"
  run_time() { "$TIME_BIN" -l "$@" 2>&1 >/dev/null; }
  # macOS format: lines like "  0.12 real", "  0.11 user", "  0.01 sys"
  parse_time() {
    echo "$1" | awk '/ real$/{r=$1} / user$/{u=$1} / sys$/{s=$1} END{printf("%.3f %.3f %.3f\n", r+0,u+0,s+0)}'
  }
fi

sum() { awk -v a="$1" -v b="$2" 'BEGIN{printf("%.6f", a+b)}'; }
avg() { awk -v s="$1" -v n="$2" 'BEGIN{printf("%.3f", s/n)}'; }

# ---------- Build steps ----------
ensure_smallint() {
  if [[ ! -f "$SMALLINT_O" ]]; then
    # expects your smallint.c with counters
    cc -O2 -c smallint.c -o "$SMALLINT_O"
  fi
}

build_plugin() {
  if [[ ! -f "$PLUGIN" ]]; then
    cmake -S . -B build -DLLVM_DIR="$BREW_LLVM_PREFIX/lib/cmake/llvm"
    cmake --build build -j
  fi
}

build_binaries() {
  # Compile benchmark to IR
  "$CLANG" -O0 -S -emit-llvm "$SRC_BENCH" -o "$IR_BENCH"

  # Baseline
  "$LLC" -filetype=obj "$IR_BENCH" -o "$BASE_O"
  cc "$BASE_O" "$SMALLINT_O" -o "$BASE_BIN"

  # Optimized (run pass)
  "$OPT" -load-pass-plugin "$PLUGIN" -passes=skeleton-pass \
    "$IR_BENCH" -S -o "$IR_OPT"

  # (Optional) sanity: ensure constants got rewritten
  # grep -E "get_small_int|box_i64" "$IR_OPT" | head -20 || true

  "$LLC" -filetype=obj "$IR_OPT" -o "$OPT_O"
  cc "$OPT_O" "$SMALLINT_O" -o "$OPT_BIN"
}

# ---------- Run one case ----------
run_case() {
  local bin="$1" mode="$2" iters="$3"
  if [[ ! -x "./$bin" ]]; then
    echo "MISSING,$bin,$mode"
    return
  fi

  local realSum=0 userSum=0 sysSum=0
  local hits=0 allocs=0

  for t in $(seq 1 "$TRIALS"); do
    out="$(run_time "./$bin" "$mode" "$iters")"
    read -r real user sys < <(parse_time "$out")
    realSum="$(sum "$realSum" "$real")"
    userSum="$(sum "$userSum" "$user")"
    sysSum="$(sum "$sysSum" "$sys")"

    # [smallint] small_hits=NN box_allocs=MM
    line="$(echo "$out" | grep '\[smallint\]' || true)"
    if [[ -n "$line" ]]; then
      h="$(echo "$line" | sed -E 's/.*small_hits=([0-9]+).*/\1/')"
      a="$(echo "$line" | sed -E 's/.*box_allocs=([0-9]+).*/\1/')"
      hits=$((hits + h))
      allocs=$((allocs + a))
    fi
  done

  local realAvg userAvg sysAvg
  realAvg="$(avg "$realSum" "$TRIALS")"
  userAvg="$(avg "$userSum" "$TRIALS")"
  sysAvg="$(avg "$sysSum" "$TRIALS")"

  echo "$bin,$mode,real=$realAvg,user=$userAvg,sys=$sysAvg,small_hits=$hits,box_allocs=$allocs"
}

# ---------- Main ----------
ensure_smallint
build_plugin
build_binaries

echo "case,mode,real,user,sys,small_hits,box_allocs"
run_case "$BASE_BIN" const_range "$ITERS_CONST"
run_case "$OPT_BIN"  const_range "$ITERS_CONST"
run_case "$BASE_BIN" mixed       "$ITERS_MIXED"
run_case "$OPT_BIN"  mixed       "$ITERS_MIXED"
run_case "$BASE_BIN" large_only  "$ITERS_LARGE"
run_case "$OPT_BIN"  large_only  "$ITERS_LARGE"
