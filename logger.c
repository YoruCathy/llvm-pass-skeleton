#include <stdio.h>
#ifdef __cplusplus
extern "C" {
#endif
void log_fdiv(void) {
  fprintf(stderr, "Floating point division detected\n");
}
#ifdef __cplusplus
}
#endif
