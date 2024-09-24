int nested_switch_example(int outer_var, int inner_var) {
    int result = 0;

    switch (outer_var) {
        default:
            result = -1; // Outer default case
            break;
        case 1:
            switch (inner_var) {
                default:
                    result = -2; // Inner default case
                case 1:
                    result = 1;
                    break;
                case 2:
                    result = 2;
                    break;
            }
            break;
        case 2:
            result = 3;
            break;
    }

    return result;
}

int main() {
    return 5;
}

