enum E {
    A = 0,
    B = 1,
};

static enum E e = B;

void entry11(const unsigned buffer_size, int buffer[]) {
    buffer[0] = e;
}