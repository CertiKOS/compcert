int switch_ex(int e){
    int a = 9;
    switch (e) {
        case 1: a++;
        case 5: a--;
        default: a += 2;
        case 3: a -= 2;
        case 4: a = 10;
    }
    return a;
}

int main(){
    return 0;
}
