struct ExampleStruct {
    int a;
    int b;
    int c;
    int d;
};

int main() {
    struct ExampleStruct example_struct;
    example_struct.a = 42;
    return example_struct.a;
}
