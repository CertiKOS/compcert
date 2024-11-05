#include <stdio.h>
#include <stdbool.h>

int main() {
    // Integer types
    int intVar = ~5;
    unsigned int uintVar = 0;
    if (!intVar) {
      return 1;
    } else {
      return 1;
    }
    if (!uintVar) {
      return 1;
    } else {
      return 1;
    }

    /*// Floating-point types*/
    float floatVar = -0.0f;
    double doubleVar = 3.14;
    if (floatVar) {
      return 1;
    } else {
      return 1;
    }
    if (doubleVar) {
      return 1;
    } else {
      return 1;
    }

    // Pointer types
    int *ptrVar = NULL;
    int value = 10;
    int *ptrVar2 = &value;
    if (ptrVar) {
      return 1;
    } else {
      return 1;
    }
    if (ptrVar2) {
      return 1;
    } else {
      return 1;
    }

    // Enumeration types
    enum { OFF, ON } enumVar = OFF;
    enum { RED = 0, GREEN = 1, BLUE = 2 } color = BLUE;
    if (enumVar) {
      return 1;
    } else {
      return 1;
    }
    if (color) {
      return 1;
    } else {
      return 1;
    }

    // _Bool and bool types
    _Bool boolVar1 = 0;
    bool boolVar2 = true;
    if (boolVar1) {
      return 1;
    } else {
      return 1;
    }
    if (boolVar2) {
      return 1;
    } else {
      return 1;
    }

    // Character types
    char charVar = '\0';
    unsigned char ucharVar = 'A';
    if (charVar) {
      return 1;
    } else {
      return 1;
    }
    if (ucharVar) {
      return 1;
    } else {
      return 1;
    }

    // Arrays and structures
    struct MyStruct {
        int member;
    } s;
    if (&s) {
      return 1;
    } else {
      return 1;
    }

    /*int arr[5];*/
    /*if (arr) {*/
    /*    printf("Array arr is true\n");*/
    /*} else {*/
    /*    printf("Array arr is false\n");*/
    /*}*/

    // Logical NOT operator
    int x = 0;
    if (!x) {
      return 1;
    } else {
      return 1;
    }

    // Logical AND and OR operators
    int y = 5;
    if (x && y) {
      return 1;
    } else {
      return 1;
    }
    if (x || y) {
      return 1;
    } else {
      return 1;
    }

    // Integer promotions
    char c = -1;
    if (c > 0) {
      return 1;
    } else {
      return 1;
    }

    // Floating-point comparisons
    double d = 1e-10;
    if (d) {
      return 1;
    } else {
      return 1;
    }
    if (d < 1e-9) {
      return 1;
    } else {
      return 1;
    }

    // Combining different types
    int a = 0;
    float b = 2.5f;
    if (a + b) {
      return 1;
    } else {
      return 1;
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

