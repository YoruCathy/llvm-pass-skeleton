#include <stdint.h>
#include <stdlib.h>

typedef struct {
    int64_t value;
} IntObj;

#define SMALL_MIN  (-5)
#define SMALL_MAX  (256)
#define SMALL_COUNT (SMALL_MAX - SMALL_MIN + 1)

static IntObj small_ints[SMALL_COUNT];
static int small_inited = 0;

static void init_small_ints(void) {
    if (small_inited) return;
    for (int i = 0; i < SMALL_COUNT; ++i) {
        small_ints[i].value = (int64_t)(SMALL_MIN + i);
    }
    small_inited = 1;
}

__attribute__((visibility("default")))
void *box_i64(int64_t v) {
    IntObj *p = (IntObj*)malloc(sizeof(IntObj));
    p->value = v;
    return (void*)p;
}

__attribute__((visibility("default")))
void *get_small_int(int64_t v) {
    init_small_ints();
    if (v < SMALL_MIN || v > SMALL_MAX) return box_i64(v);
    return (void*)&small_ints[v - SMALL_MIN];
}
