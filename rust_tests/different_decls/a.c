#include <stdio.h>

typedef struct example_struct{
  int a;
  int b;
} example_struct;

void print_struct_2(){
  example_struct tmp = {.a =5, .b = 6};
  printf("example struct values %d %d", tmp.a, tmp.b);
}
