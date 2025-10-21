#include <stdio.h>

float fdivf(float a, float b) {
    return a / b;
}

double fdivd(double a, double b) {
    return a / b;
}

int idiv(int a, int b) {
    return a / b;
}

int main() {
    float xf = fdivf(7.0f, 3.5f);
    float yf = fdivf(2.0f, 0.0f);     // floating-point divide by zero

    double xd = fdivd(10.0, 4.0);
    double yd = fdivd(10.0, 0.0);     // floating-point divide by zero

    int xi = idiv(8, 2);
    int yi = idiv(8, 0);              // integer divide by zero

    printf("Results: %f %f %f %f %d %d\n", xf, yf, xd, yd, xi, yi);
    return 0;
}
