#!/usr/bin/env bash
set -euo pipefail

CLANG="$(brew --prefix llvm)/bin/clang"
OPT="$(brew --prefix llvm)/bin/opt"
PASS="./build/skeleton/licm/LICMPass.dylib"

ROOT="$(pwd)"
THIRD="$ROOT/build/third_party"
EMBENCH_DIR="$THIRD/embench-iot"
OUTDIR="$ROOT/build/embench_licm"
mkdir -p "$THIRD" "$OUTDIR"

# Keep a small, host-friendly subset; remove any that fail on macOS.
BENCHES="aha-mont64 crc32 edn minver cubic nbody matmult-int primecount"

if [ ! -d "$EMBENCH_DIR" ]; then
  echo "==> Cloning embench-iot…"
  git clone --depth=1 https://github.com/embench/embench-iot.git "$EMBENCH_DIR"
fi

# Host config
HOST_DEFS="-DEMBENCH_NATIVE -DCPU_MHZ=3000 -DHAVE_PRINTF=1"
HOST_INCS="-I$EMBENCH_DIR/include -I$EMBENCH_DIR/support"
HOST_WARN="-Wall -Wno-unused-function -Wno-implicit-function-declaration -Wno-macro-redefined"

discover_sources() {
  b="$1"
  d1="$EMBENCH_DIR/src/$b"
  if [ -d "$d1" ]; then find "$d1" -type f -name '*.c' | sort; return; fi
  d2="$EMBENCH_DIR/benchmarks/$b/src"
  if [ -d "$d2" ]; then find "$d2" -type f -name '*.c' | sort; return; fi
  d3="$EMBENCH_DIR/$b"
  if [ -d "$d3" ]; then find "$d3" -type f -name '*.c' | sort; return; fi
  find "$EMBENCH_DIR" -type d -name "$b" -exec find {} -type f -name '*.c' \; | sort
}

# Build a merged TU: include all bench sources + weak stubs + tiny host main.
make_merged_tu() {
  bench="$1"; merged="$2"
  SRCS="$(discover_sources "$bench")"
  if [ -z "$SRCS" ]; then
    echo "   !! no sources found for $bench — skipping"
    return 1
  fi
  {
    echo "/* Auto-generated merged TU for $bench */"
    for s in $SRCS; do
      rel="${s#$EMBENCH_DIR/}"
      echo "#include \"$EMBENCH_DIR/$rel\""
    done
    # ---- Weak fallbacks for missing board/support symbols ----
    cat <<'EOF'
__attribute__((weak)) void srand_beebs(unsigned int seed) {
  static unsigned long beebs_seed = 1;
  beebs_seed = seed ? seed : 1;
}
__attribute__((weak)) int rand_beebs(void) {
  static unsigned long beebs_seed = 1;
  beebs_seed = beebs_seed * 1103515245u + 12345u;
  return (int)((beebs_seed >> 16) & 0x7fff);
}
#ifndef LOCAL_SCALE_FACTOR
#define LOCAL_SCALE_FACTOR 100
#endif
extern int benchmark_body(int rpt);
int main(void) {
  volatile int r = benchmark_body(LOCAL_SCALE_FACTOR * CPU_MHZ);
  (void)r;
  return 0;
}
EOF
  } > "$merged"
}

compile_bc() {
  src="$1"; outbc="$2"
  "$CLANG" -O0 -Xclang -disable-O0-optnone -std=c99 $HOST_WARN \
           $HOST_INCS $HOST_DEFS \
           -emit-llvm -c "$src" -o "$outbc"
}

link_exe_from_bc() {
  bc="$1"; exe="$2"
  "$CLANG" -O0 -c "$bc" -o "${bc%.bc}.o"
  "$CLANG" -O0 "${bc%.bc}.o" -lm -o "$exe"
}

measure_time() {
  (/usr/bin/time -lp "$1" >/dev/null) 2>&1 | awk '/real/ {print $2; exit}'
}


csv="$OUTDIR/results.csv"
printf "benchmark,baseline_s,licm_s,speedup\n" > "$csv"
printf "\n%-12s %-12s %-12s %-10s\n" "Benchmark" "Baseline(s)" "LICM(s)" "Speedup"

for b in $BENCHES; do
  echo "==> Building $b …"
  work="$OUTDIR/$b"
  mkdir -p "$work"
  merged="$work/merged_$b.c"
  if ! make_merged_tu "$b" "$merged"; then
    continue
  fi

  # Baseline: mem2reg + loop-simplify
  base_bc="$work/${b}_base.bc"
  compile_bc "$merged" "$base_bc"
  "$OPT" -passes="mem2reg,loop-simplify" "$base_bc" -o "$base_bc"
  link_exe_from_bc "$base_bc" "$work/${b}_base.out"

  # LICM: mem2reg + loop-simplify + my-licm
  licm_bc="$work/${b}_licm.bc"
  compile_bc "$merged" "$licm_bc"
  "$OPT" -load-pass-plugin "$PASS" -passes="mem2reg,loop-simplify,my-licm" "$licm_bc" -o "$licm_bc"
  link_exe_from_bc "$licm_bc" "$work/${b}_licm.out"

  tb="$(measure_time "$work/${b}_base.out" || echo nan)"
  tl="$(measure_time "$work/${b}_licm.out" || echo nan)"
  spd="$(awk -v b="$tb" -v l="$tl" 'BEGIN{ if (b ~ /^[0-9.]+$/ && l ~ /^[0-9.]+$/ && l+0>0) printf("%.3f", (b+0)/(l+0)); else print "nan"; }')"

  printf "%-12s %-12s %-12s %-10s\n" "$b" "$tb" "$tl" "$spd"
  printf "%s,%s,%s,%s\n" "$b" "$tb" "$tl" "$spd" >> "$csv"
done

