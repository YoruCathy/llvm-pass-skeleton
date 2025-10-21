#include <stdio.h>

void log_fdiv(void) {
    fprintf(stderr, "Floating-point division detected\n");
}

void log_divzero_check(double rhs) {
    if (rhs == 0.0) {
        fprintf(stderr, "Runtime divide-by-zero detected\n");
    }
}
