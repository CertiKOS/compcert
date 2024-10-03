#include <stdio.h>
#include <stdbool.h>

int main() {
    // Integer types
    int intVar = ~5;
    unsigned int uintVar = 0;
    if (!intVar) {
        printf("intVar is true\n");
    } else {
        printf("intVar is false\n");
    }
    if (!uintVar) {
        printf("uintVar is true\n");
    } else {
        printf("uintVar is false\n");
    }

    // Floating-point types
    float floatVar = -0.0f;
    double doubleVar = 3.14;
    if (floatVar) {
        printf("floatVar is true\n");
    } else {
        printf("floatVar is false\n");
    }
    if (doubleVar) {
        printf("doubleVar is true\n");
    } else {
        printf("doubleVar is false\n");
    }

    // Pointer types
    int *ptrVar = NULL;
    int value = 10;
    int *ptrVar2 = &value;
    if (ptrVar) {
        printf("ptrVar is true\n");
    } else {
        printf("ptrVar is false\n");
    }
    if (ptrVar2) {
        printf("ptrVar2 is true\n");
    } else {
        printf("ptrVar2 is false\n");
    }

    // Enumeration types
    enum { OFF, ON } enumVar = OFF;
    enum { RED = 0, GREEN = 1, BLUE = 2 } color = BLUE;
    if (enumVar) {
        printf("enumVar is true\n");
    } else {
        printf("enumVar is false\n");
    }
    if (color) {
        printf("color is true\n");
    } else {
        printf("color is false\n");
    }

    // _Bool and bool types
    _Bool boolVar1 = 0;
    bool boolVar2 = true;
    if (boolVar1) {
        printf("boolVar1 is true\n");
    } else {
        printf("boolVar1 is false\n");
    }
    if (boolVar2) {
        printf("boolVar2 is true\n");
    } else {
        printf("boolVar2 is false\n");
    }

    // Character types
    char charVar = '\0';
    unsigned char ucharVar = 'A';
    if (charVar) {
        printf("charVar is true\n");
    } else {
        printf("charVar is false\n");
    }
    if (ucharVar) {
        printf("ucharVar is true\n");
    } else {
        printf("ucharVar is false\n");
    }

    // Arrays and structures
    struct MyStruct {
        int member;
    } s;
    if (&s) {
        printf("Address of s is true\n");
    } else {
        printf("Address of s is false\n");
    }

    int arr[5];
    if (arr) {
        printf("Array arr is true\n");
    } else {
        printf("Array arr is false\n");
    }

    // Logical NOT operator
    int x = 0;
    if (!x) {
        printf("!x is true\n");
    } else {
        printf("!x is false\n");
    }

    // Logical AND and OR operators
    int y = 5;
    if (x && y) {
        printf("x && y is true\n");
    } else {
        printf("x && y is false\n");
    }
    if (x || y) {
        printf("x || y is true\n");
    } else {
        printf("x || y is false\n");
    }

    // Integer promotions
    char c = -1;
    if (c > 0) {
        printf("c > 0 is true\n");
    } else {
        printf("c > 0 is false\n");
    }

    // Floating-point comparisons
    double d = 1e-10;
    if (d) {
        printf("d is true\n");
    } else {
        printf("d is false\n");
    }
    if (d < 1e-9) {
        printf("d is less than 1e-9\n");
    } else {
        printf("d is not less than 1e-9\n");
    }

    // Combining different types
    int a = 0;
    float b = 2.5f;
    if (a + b) {
        printf("a + b is true\n");
    } else {
        printf("a + b is false\n");
    }

    // Uninitialized variable (commented out to prevent undefined behavior)
    // int uninitializedVar;
    // if (uninitializedVar) {
    //     printf("uninitializedVar is true\n");
    // } else {
    //     printf("uninitializedVar is false\n");
    // }

    return 0;
}

