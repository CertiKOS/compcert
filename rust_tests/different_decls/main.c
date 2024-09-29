typedef struct example_struct{
  float e;
  float f;
  float g;
} example_struct;

void print_struct();

void main(){
  example_struct a =  (example_struct){.e=5.0};
  print_struct();
}
