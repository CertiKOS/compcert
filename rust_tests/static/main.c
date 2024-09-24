static int a = 9;

int example() {
  static int a = 0;
  a++;
  return a;
}

int example_2(){
  a++;
}

int main() {

}
