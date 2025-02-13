// IDK why this is needed
// https://stackoverflow.com/questions/13525774/clang-and-float128-bug-error
typedef long double __float128;
#include <stddef.h>

typedef struct {
    int a;
    float mod[3];
} use;

size_t get_offset(size_t idx) {
    return offsetof(use, mod) + sizeof(float) * idx;
}

struct yield {
    int a;
    float mod[3];
};

size_t get_offset2(size_t idx) {
    return offsetof(struct yield, mod) + sizeof(float) * idx;
}
