#include <stddef.h>

void entry_sizet(unsigned n, int buf[]) {
  if (n < 10) return;

  size_t z = 5;
  buf[z] = 8;
}
