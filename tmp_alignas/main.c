#include <stdalign.h>

union  _Alignas(16) MyUnion {
    char a;
    int b;
    double c;
};

struct _Alignas(8) MyStruct {
    char c;
    int i;
};
struct MyStruct2 {
    char a;
    int b __attribute__((aligned(16)));
    char c;
};

int main() {
    alignas(128) int a[4];
    struct MyStruct s = {'A', 42};

    struct MyStruct2 s2 = {'A', 42, 'C'};

    union MyUnion myunion;

    return 0;
}
