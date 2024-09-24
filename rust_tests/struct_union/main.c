struct ExampleStruct {
    int a;
    float b;
    char c;
};

union ExampleUnion {
    int i;
    float f;
    char c;
};

int main() {
    struct ExampleStruct example_struct = { .a = 1, };
    example_struct.a = 42;
    example_struct.b = 42.0f;
    example_struct.b = 'f';
    union ExampleUnion example_union;
    example_union.i = 42;

}
