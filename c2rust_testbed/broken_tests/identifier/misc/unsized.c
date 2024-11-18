//! skip_translation

struct Foo {
  int i;
  char unspec[];
};

int main(void) {
  /* TODO this is not allowed by clang even. Not sure why it's in here. */
  /*struct Foo f1 = { 1, "hello" };*/
  /**/
  /*printf("%s!", f1.unspec);*/
  /* TODO gnu extension. Not supported */
  /*printf("%d", sizeof(f1.unspec));*/
}
