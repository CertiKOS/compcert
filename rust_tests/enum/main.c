#include <stdio.h>

// Define an enum for colors
enum Color {
    RED,
    GREEN,
    BLUE
};

int main() {
    // Declare a variable of type enum Color
    enum Color favoriteColor;

    // Assign a value to favoriteColor
    favoriteColor = GREEN;

    // Print the value of favoriteColor
    printf("Favorite color value: %d\n", favoriteColor);

    return 0;
}
