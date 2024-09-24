#include <stdarg.h>
#include <stdio.h>

// Variadic function to calculate the sum of its arguments
int sum(int count, ...) {
    va_list args;
    int result = 0;

    // Initialize the argument list
    va_start(args, count);

    // Loop through all arguments
    for (int i = 0; i < count; ++i) {
        result += va_arg(args, int);
    }

    // Clean up the argument list
    va_end(args);

    return result;
}

int main() {
    // Example usage of the variadic function
    int result = sum(5, 1, 2, 3, 4, 5);
    printf("The sum is: %d\n", result);
    return 0;
}

