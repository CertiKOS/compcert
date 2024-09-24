#include <stdio.h>

typedef struct example_struct {
  double f1;
} example_struct;

void print_ex_2(){
  example_struct a = {.f1 = 0.1};
  printf("example struct: %f\n", a.f1);
}
