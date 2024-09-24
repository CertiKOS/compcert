struct ExampleStruct;
union ExampleUnion;
struct ExampleStruct {
  int a;
  float b;
  signed char c;
};

union ExampleUnion {
  int i;
  float f;
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
  struct ExampleStruct example_struct;
  union ExampleUnion example_union;
  example_struct.a = 1;
  example_struct.b = 0;
  example_struct.c = 0;
  example_struct.a = 42;
  example_struct.b = 42f;
  example_struct.b = 102;
  example_union.i = 42;
  return 0;
}


