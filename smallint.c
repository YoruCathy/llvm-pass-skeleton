// smallint.c — boxed-int runtime with small-int interning + counters
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

typedef struct {
    int64_t value;
} IntObj;

#define SMALL_MIN  (-5)
#define SMALL_MAX  (256)
#define SMALL_COUNT (SMALL_MAX - SMALL_MIN + 1)

static IntObj small_ints[SMALL_COUNT];
static int small_inited = 0;

// Counters
static unsigned long long small_hits = 0;   // fast-path singletons
static unsigned long long box_allocs = 0;   // malloc-backed boxes

static void init_small_ints(void) {
    if (small_inited) return;
    for (int i = 0; i < SMALL_COUNT; ++i) {
        small_ints[i].value = (int64_t)(SMALL_MIN + i);
    }
    small_inited = 1;
}

__attribute__((visibility("default")))
void *box_i64(int64_t v) {
    // Slow path: heap allocation
    IntObj *p = (IntObj*)malloc(sizeof(IntObj));
    p->value = v;
    box_allocs++;
    return (void*)p;
}

__attribute__((visibility("default")))
void *get_small_int(int64_t v) {
    init_small_ints();
    if (v < SMALL_MIN || v > SMALL_MAX) {
        return box_i64(v);  // falls back to slow path; counts in box_allocs
    }
    small_hits++;
    return (void*)&small_ints[v - SMALL_MIN];
}

static void smallint_report(void) {
    fprintf(stderr, "[smallint] small_hits=%llu box_allocs=%llu\n",
            small_hits, box_allocs);
}

__attribute__((constructor))
static void smallint_ctor(void) {
    atexit(smallint_report);
}
