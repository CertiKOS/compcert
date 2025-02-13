// IDK why this is needed
// https://stackoverflow.com/questions/13525774/clang-and-float128-bug-error
typedef long double __float128;
#include <stddef.h>


void entry_sizet(unsigned n, int buf[]) {
  if (n < 10) return;

  size_t z = 5;
  buf[z] = 8;
}
