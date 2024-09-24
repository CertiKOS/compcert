union MyUnion;
struct MyStruct;
struct MyStruct2;
union MyUnion _Alignas(16) {
  signed char a;
  int b;
  double c;
};

struct MyStruct _Alignas(8) {
  signed char c;
  int i;
};

struct MyStruct2 {
  signed char a;
  int b;
  signed char c;
};

extern unsigned int __compcert_va_int32(void *);
extern unsigned long long __compcert_va_int64(void *);
extern double __compcert_va_float64(void *);
extern void *__compcert_va_composite(void *, unsigned long long);
extern long long __compcert_i64_dtos(double);
extern unsigned long long __compcert_i64_dtou(double);
extern double __compcert_i64_stod(long long);
extern double __compcert_i64_utod(unsigned long long);
extern float __compcert_i64_stof(long long);
extern float __compcert_i64_utof(unsigned long long);
extern long long __compcert_i64_sdiv(long long, long long);
extern unsigned long long __compcert_i64_udiv(unsigned long long, unsigned long long);
extern long long __compcert_i64_smod(long long, long long);
extern unsigned long long __compcert_i64_umod(unsigned long long, unsigned long long);
extern long long __compcert_i64_shl(long long, int);
extern unsigned long long __compcert_i64_shr(unsigned long long, int);
extern long long __compcert_i64_sar(long long, int);
extern long long __compcert_i64_smulh(long long, long long);
extern unsigned long long __compcert_i64_umulh(unsigned long long, unsigned long long);
extern void __builtin_debug(int, ...);
int main(void);
int main(void)
{
  int a[4];
  struct MyStruct s;
  struct MyStruct2 s2;
  union MyUnion myunion;
  int c;
  int b;
  s.c = 65;
  s.i = 42;
  s2.a = 65;
  s2.b = 42;
  s2.c = 67;
  c = __alignof__(struct MyStruct);
  b = sizeof(struct MyStruct);
  return 0;
  return 0;
}


