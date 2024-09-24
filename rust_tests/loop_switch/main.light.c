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
int switch_in_loop(int, int, int);
int main(void);
int switch_in_loop(int size, int a, int b)
{
  int sum;
  sum = 0;
  while (1) {
    /*skip*/;
    switch (size) {
      case 0:
        continue;
      case 1:
        sum = sum + 10;
        break;
      case 2:
        sum = sum + 20;
        break;
      default:
        sum = sum + 5;
        break;
      
    }
  }
  return sum;
}

int main(void)
{
  int a;
  register int $61;
  $61 = switch_in_loop(5, 6, 7);
  a = $61;
  return 0;
}


