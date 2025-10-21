#include <stdio.h>
float  fdivf(float a, float b) { return a / b; }
double fdivd(double a, double b) { return a / b; }
int main(void) {
  printf("%f %f\n", fdivf(7.0f, 3.5f), fdivd(10.0, 4.0));
  return 0;
}