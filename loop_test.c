int test(int n, int a) {
  int x = 0;
  for (int i = 0; i < n; ++i) {
    x += a * 3;  // loop-invariant multiply
  }
  return x;
}
