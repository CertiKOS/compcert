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
extern int printf(signed char *, ...);
int sum(int, ...);
int main(void);
signed char const __stringlit_1[16] = "The sum is: %d\012";

int sum(int count,...)
{
  void *args;
  int result;
  int i;
  register unsigned int $63;
  result = 0;
  __builtin_va_start(&args);
  i = 0;
  for (; 1; i = i + 1) {
    if (! (i < count)) {
      break;
    }
    $63 = __compcert_va_int32(&args);
    result = result + (int) $63;
  }
  return result;
}

int main(void)
{
  int result;
  register int $63;
  $63 = sum(5, 1, 2, 3, 4, 5);
  result = $63;
  printf(__stringlit_1, result);
  return 0;
  return 0;
}


