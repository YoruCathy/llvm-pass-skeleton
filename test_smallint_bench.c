// test_smallint_bench.c
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h> 

void *box_i64(long long);     // slow path (baseline API)
void *get_small_int(long long); // fast path used only after your pass rewrites calls

static volatile unsigned long long sink; // prevent aggressive DCE

static void bench_const_range(size_t N) {
    for (size_t i = 0; i < N; ++i) {
        // compile-time constants in [-5,256]
        void *a = box_i64(-5);
        void *b = box_i64(42);
        void *c = box_i64(256);
        sink += (unsigned long long)(uintptr_t)a;
        sink += (unsigned long long)(uintptr_t)b;
        sink += (unsigned long long)(uintptr_t)c;
    }
}

static void bench_mixed(size_t N) {
    for (size_t i = 0; i < N; ++i) {
        long long v = (long long)(i % 1000) - 100; // roughly [-100,899]
        // ~90% in [-5,256], ~10% outside
        void *p = box_i64(v);
        sink += (unsigned long long)(uintptr_t)p;
    }
}

static void bench_large_only(size_t N) {
    for (size_t i = 0; i < N; ++i) {
        long long v = 1000000LL + (long long)(i & 1023); // always out of range
        void *p = box_i64(v);
        sink += (unsigned long long)(uintptr_t)p;
    }
}

static size_t parse_or_default(const char *s, size_t dflt) {
    if (!s) return dflt;
    char *end = NULL;
    unsigned long long v = strtoull(s, &end, 10);
    return (end && *end == '\0' && v > 0) ? (size_t)v : dflt;
}

int main(int argc, char **argv) {
    const char *mode = (argc > 1 ? argv[1] : "const_range");
    size_t N = parse_or_default(argc > 2 ? argv[2] : NULL, 1000000ULL);

    if (mode && !strcmp(mode, "const_range"))      bench_const_range(N);
    else if (mode && !strcmp(mode, "mixed"))       bench_mixed(N);
    else if (mode && !strcmp(mode, "large_only"))  bench_large_only(N);
    else {
        fprintf(stderr, "usage: %s {const_range|mixed|large_only} [iters]\n", argv[0]);
        return 2;
    }

    // touch sink so the loop isn't removed
    if (sink == 0xdeadbeefULL) printf("sink=%llu\n", sink);
    return 0;
}
