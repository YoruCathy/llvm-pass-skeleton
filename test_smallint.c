// test_smallint.c
#include <stdio.h>
#include <stdint.h>
void *box_i64(int64_t);
void *get_small_int(int64_t);

int main() {
    // Constants
    void *a = box_i64(-5);
    void *b = box_i64(42);
    void *c = box_i64(256);

    // Variable
    int64_t x = 100;
    void *d = box_i64(x);     // fast-path
    x = 9999;
    void *e = box_i64(x);     // slow-path

    printf("%p %p %p %p %p\n", a,b,c,d,e);
    return 0;
}
