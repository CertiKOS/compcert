int switch_in_loop(int size, int a, int b) {
    int sum = 0;

    while(1){
        switch (size) {
            case 0:
                continue;
            case 1:
                sum += 10;
                break;
            case 2:
                sum += 20;
                break;
            default:
                sum += 5;
                break;
        }
    }

    return sum;
}

int main() {
    int a = switch_in_loop(5, 6, 7);
}
