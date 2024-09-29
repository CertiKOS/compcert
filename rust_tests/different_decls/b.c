#include <stdio.h>

typedef struct example_struct{
  float e;
} example_struct;

void print_struct(){
  example_struct tmp = {.e = 5.0};
  printf("example struct values %d", tmp.e);
}
