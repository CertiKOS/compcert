#include <stdio.h>

typedef struct example_struct {
  int i1;
} example_struct;

void print_ex_1(){
  example_struct a = {.i1 = 1};
  printf("example struct: %d\n", a.i1);
}
