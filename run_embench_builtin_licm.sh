#!/usr/bin/env bash
set -euo pipefail

# === Tools ===
CLANG="$(brew --prefix llvm)/bin/clang"
OPT="$(brew --prefix llvm)/bin/opt"

ROOT="$(pwd)"
THIRD="$ROOT/build/third_party"
EMBENCH_DIR="$THIRD/embench-iot"
OUTDIR="$ROOT/build/embench_licm"
mkdir -p "$THIRD" "$OUTDIR"

# === Benchmarks (numeric subset that builds cleanly on macOS) ===
BENCHES="aha-mont64 crc32 cubic edn matmult-int minver nbody sha"

# === Timing config ===
REPS=20  # your requested reps

# === Host build flags ===
HOST_DEFS="-DEMBENCH_NATIVE -DCPU_MHZ=6000 -DHAVE_PRINTF=1"
HOST_INCS="-I$EMBENCH_DIR/include -I$EMBENCH_DIR/support"
HOST_WARN="-Wall -Wno-unused-function -Wno-implicit-function-declaration -Wno-macro-redefined"

if [ ! -d "$EMBENCH_DIR" ]; then
  echo "==> Cloning embench-iot…"
  git clone --depth=1 https://github.com/embench/embench-iot.git "$EMBENCH_DIR"
fi

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

# === Build a merged TU: include all C files + weak stubs + tiny host main ===
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
    cat <<'EOF'
__attribute__((weak)) void srand_beebs(unsigned int seed) {
  static unsigned long beebs_seed = 1; (void)seed; beebs_seed = seed ? seed : 1;
}
__attribute__((weak)) int rand_beebs(void) {
  static unsigned long beebs_seed = 1; beebs_seed = beebs_seed * 1103515245u + 12345u;
  return (int)((beebs_seed >> 16) & 0x7fff);
}
__attribute__((weak)) void *memcpy_beebs(void *dst, const void *src, unsigned n) {
  unsigned char *d = (unsigned char*)dst; const unsigned char *s = (const unsigned char*)src;
  while (n--) *d++ = *s++; return dst;
}
__attribute__((weak)) void *memset_beebs(void *dst, int v, unsigned n) {
  unsigned char *d = (unsigned char*)dst; unsigned char c=(unsigned char)v;
  while (n--) *d++ = c; return dst;
}
#ifndef LOCAL_SCALE_FACTOR
#define LOCAL_SCALE_FACTOR 100
#endif
/* Benchmarks define: int benchmark_body(int rpt); just declare and call it. */
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

measure_time_once() {
  (/usr/bin/time -lp "$1" >/dev/null) 2>&1 | awk '/real/ {print $2; exit}'
}

# Stats from a tmp list of times
compute_stats_from_file() {
  f="$1"
  cnt="$(wc -l < "$f" | tr -d ' ')"
  if [ "$cnt" -eq 0 ] || [ "$cnt" = "0" ]; then
    echo "nan,nan,nan"   # median,mean,var
    return
  fi
  mid=$(( (cnt + 1) / 2 ))
  med="$(sort -n "$f" | sed -n "${mid}p")"
  mv="$(awk '{
      n+=1; s+=$1; s2+=$1*$1
    } END {
      if (n==0) {print "nan,nan"; exit}
      m=s/n; v=s2/n - m*m;
      printf("%.6f,%.6f", m, v<0?0:v);
    }' "$f")"
  echo "$med,$mv"
}

measure_time_stats() {
  exe="$1"; reps="$2"
  tmp="$(mktemp)"; i=0
  while [ $i -lt "$reps" ]; do
    t="$(measure_time_once "$exe" || true)"
    [ -n "$t" ] && echo "$t" >> "$tmp"
    i=$((i+1))
  done
  stats="$(compute_stats_from_file "$tmp")"
  rm -f "$tmp"
  echo "$stats"   # median,mean,var
}

# === Try a few new-PM pipelines for builtin LICM ===
run_opt_builtin_licm() {
  inbc="$1"; outbc="$2"
  # simplest robust new-PM pipeline
  if "$OPT" -passes="mem2reg,loop-simplify,loop-rotate,lcssa,licm" "$inbc" -o "$outbc" 2>_opt_err.txt; then
    rm -f _opt_err.txt
    return 0
  fi
  echo "   !! builtin LICM failed, stderr:"
  sed 's/^/      /' _opt_err.txt || true
  rm -f _opt_err.txt
  return 1
}


ts="$(date +%Y%m%d_%H%M%S)"
csv="$OUTDIR/results_builtin_${ts}.csv"
printf "benchmark,baseline_median_s,baseline_mean_s,baseline_var_s2,builtin_licm_median_s,builtin_licm_mean_s,builtin_licm_var_s2,speedup_median,speedup_mean\n" > "$csv"

printf "\n%-14s %-11s %-12s %-11s %-12s\n" "Benchmark" "Base_med" "Builtin_med" "Spdup_med" "Spdup_mean"

for b in $BENCHES; do
  echo "==> Building $b …"
  work="$OUTDIR/${b}_builtin"
  mkdir -p "$work"
  merged="$work/merged_$b.c"
  if ! make_merged_tu "$b" "$merged"; then
    continue
  fi

  # Baseline (no LICM)
  base_bc="$work/${b}_base.bc"
  compile_bc "$merged" "$base_bc"
  "$OPT" -passes="mem2reg,loop-simplify" "$base_bc" -o "$base_bc"
  link_exe_from_bc "$base_bc" "$work/${b}_base.out"

  # Builtin LICM (new PM variants)
  licm_bc="$work/${b}_licm.bc"
  compile_bc "$merged" "$licm_bc"
  if ! run_opt_builtin_licm "$licm_bc" "$licm_bc"; then
    echo "   !! skipping timing for $b due to LICM failure"
    continue
  fi
  link_exe_from_bc "$licm_bc" "$work/${b}_licm.out"

  # Stats
  IFS=, read -r base_med base_mean base_var <<<"$(measure_time_stats "$work/${b}_base.out" "$REPS")"
  IFS=, read -r licm_med licm_mean licm_var <<<"$(measure_time_stats "$work/${b}_licm.out" "$REPS")"

  # Speedups
  spd_med="$(awk -v b="$base_med" -v l="$licm_med" 'BEGIN{ if (b ~ /^[0-9.]+$/ && l ~ /^[0-9.]+$/ && l+0>0) printf("%.3f",(b+0)/(l+0)); else print "nan"; }')"
  spd_mean="$(awk -v b="$base_mean" -v l="$licm_mean" 'BEGIN{ if (b ~ /^[0-9.]+$/ && l ~ /^[0-9.]+$/ && l+0>0) printf("%.3f",(b+0)/(l+0)); else print "nan"; }')"

  printf "%-14s %-11s %-12s %-11s %-12s\n" "$b" "$base_med" "$licm_med" "$spd_med" "$spd_mean"
  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
    "$b" "$base_med" "$base_mean" "$base_var" "$licm_med" "$licm_mean" "$licm_var" "$spd_med" "$spd_mean" >> "$csv"
done

echo
echo "CSV written to: $csv"
