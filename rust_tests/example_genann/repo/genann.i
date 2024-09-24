# 1 "genann.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 412 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "genann.c" 2
# 26 "genann.c"
int const GLOBAL_CONST = 5;

# 1 "./genann.h" 1
# 30 "./genann.h"
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 1 3
# 64 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 1 3
# 68 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/cdefs.h" 1 3
# 649 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/cdefs.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_symbol_aliasing.h" 1 3
# 650 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/cdefs.h" 2 3
# 715 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/cdefs.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_posix_availability.h" 1 3
# 716 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/cdefs.h" 2 3
# 69 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/Availability.h" 1 3
# 135 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/Availability.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/AvailabilityVersions.h" 1 3
# 136 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/Availability.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/AvailabilityInternal.h" 1 3
# 137 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/Availability.h" 2 3
# 70 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 2 3

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types.h" 1 3
# 27 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types.h" 1 3
# 33 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/_types.h" 1 3
# 34 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/_types.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/_types.h" 1 3
# 15 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/_types.h" 3
typedef char __int8_t;

typedef unsigned char __uint8_t;
typedef short __int16_t;
typedef unsigned short __uint16_t;
typedef int __int32_t;
typedef unsigned int __uint32_t;
typedef long long __int64_t;
typedef unsigned long long __uint64_t;

typedef long __darwin_intptr_t;
typedef unsigned int __darwin_natural_t;
# 46 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/_types.h" 3
typedef int __darwin_ct_rune_t;





typedef union {
 char __mbstate8[128];
 long long _mbstateL;
} __mbstate_t;

typedef __mbstate_t __darwin_mbstate_t;


typedef long int __darwin_ptrdiff_t;







typedef long unsigned int __darwin_size_t;







typedef void * __darwin_va_list;



typedef int __darwin_wchar_t;




typedef __darwin_wchar_t __darwin_rune_t;


typedef int __darwin_wint_t;




typedef unsigned long __darwin_clock_t;
typedef __uint32_t __darwin_socklen_t;
typedef long __darwin_ssize_t;
typedef long __darwin_time_t;
# 35 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/_types.h" 2 3
# 34 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types.h" 2 3
# 55 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types.h" 3
typedef __int64_t __darwin_blkcnt_t;
typedef __int32_t __darwin_blksize_t;
typedef __int32_t __darwin_dev_t;
typedef unsigned int __darwin_fsblkcnt_t;
typedef unsigned int __darwin_fsfilcnt_t;
typedef __uint32_t __darwin_gid_t;
typedef __uint32_t __darwin_id_t;
typedef __uint64_t __darwin_ino64_t;

typedef __darwin_ino64_t __darwin_ino_t;



typedef __darwin_natural_t __darwin_mach_port_name_t;
typedef __darwin_mach_port_name_t __darwin_mach_port_t;
typedef __uint16_t __darwin_mode_t;
typedef __int64_t __darwin_off_t;
typedef __int32_t __darwin_pid_t;
typedef __uint32_t __darwin_sigset_t;
typedef __int32_t __darwin_suseconds_t;
typedef __uint32_t __darwin_uid_t;
typedef __uint32_t __darwin_useconds_t;
typedef unsigned char __darwin_uuid_t[16];
typedef char __darwin_uuid_string_t[37];

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_pthread/_pthread_types.h" 1 3
# 57 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_pthread/_pthread_types.h" 3
struct __darwin_pthread_handler_rec {
 void (*__routine)(void *);
 void *__arg;
 struct __darwin_pthread_handler_rec *__next;
};

struct _opaque_pthread_attr_t {
 long __sig;
 char __opaque[56];
};

struct _opaque_pthread_cond_t {
 long __sig;
 char __opaque[40];
};

struct _opaque_pthread_condattr_t {
 long __sig;
 char __opaque[8];
};

struct _opaque_pthread_mutex_t {
 long __sig;
 char __opaque[56];
};

struct _opaque_pthread_mutexattr_t {
 long __sig;
 char __opaque[8];
};

struct _opaque_pthread_once_t {
 long __sig;
 char __opaque[8];
};

struct _opaque_pthread_rwlock_t {
 long __sig;
 char __opaque[192];
};

struct _opaque_pthread_rwlockattr_t {
 long __sig;
 char __opaque[16];
};

struct _opaque_pthread_t {
 long __sig;
 struct __darwin_pthread_handler_rec *__cleanup_stack;
 char __opaque[8176];
};

typedef struct _opaque_pthread_attr_t __darwin_pthread_attr_t;
typedef struct _opaque_pthread_cond_t __darwin_pthread_cond_t;
typedef struct _opaque_pthread_condattr_t __darwin_pthread_condattr_t;
typedef unsigned long __darwin_pthread_key_t;
typedef struct _opaque_pthread_mutex_t __darwin_pthread_mutex_t;
typedef struct _opaque_pthread_mutexattr_t __darwin_pthread_mutexattr_t;
typedef struct _opaque_pthread_once_t __darwin_pthread_once_t;
typedef struct _opaque_pthread_rwlock_t __darwin_pthread_rwlock_t;
typedef struct _opaque_pthread_rwlockattr_t __darwin_pthread_rwlockattr_t;
typedef struct _opaque_pthread_t *__darwin_pthread_t;
# 81 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types.h" 2 3
# 28 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types.h" 2 3
# 40 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types.h" 3
typedef int __darwin_nl_item;
typedef int __darwin_wctrans_t;

typedef __uint32_t __darwin_wctype_t;
# 72 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 2 3



# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_va_list.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_va_list.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/types.h" 1 3
# 37 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/types.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 1 3
# 52 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_int8_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_int8_t.h" 3
typedef signed char int8_t;
# 53 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_int16_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_int16_t.h" 3
typedef short int16_t;
# 54 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_int32_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_int32_t.h" 3
typedef int int32_t;
# 55 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_int64_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_int64_t.h" 3
typedef long long int64_t;
# 56 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_u_int8_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_u_int8_t.h" 3
typedef unsigned char u_int8_t;
# 58 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_u_int16_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_u_int16_t.h" 3
typedef unsigned short u_int16_t;
# 59 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_u_int32_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_u_int32_t.h" 3
typedef unsigned int u_int32_t;
# 60 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_u_int64_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_u_int64_t.h" 3
typedef unsigned long long u_int64_t;
# 61 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3


typedef int64_t register_t;




# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_intptr_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_intptr_t.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/types.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_intptr_t.h" 2 3

typedef __darwin_intptr_t intptr_t;
# 69 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_uintptr_t.h" 1 3
# 30 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_uintptr_t.h" 3
typedef unsigned long uintptr_t;
# 70 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 2 3




typedef u_int64_t user_addr_t;
typedef u_int64_t user_size_t;
typedef int64_t user_ssize_t;
typedef int64_t user_long_t;
typedef u_int64_t user_ulong_t;
typedef int64_t user_time_t;
typedef int64_t user_off_t;
# 101 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/types.h" 3
typedef u_int64_t syscall_arg_t;
# 38 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/types.h" 2 3
# 32 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_va_list.h" 2 3
typedef __darwin_va_list va_list;
# 76 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_size_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_size_t.h" 3
typedef __darwin_size_t size_t;
# 77 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_null.h" 1 3
# 78 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 2 3

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/stdio.h" 1 3
# 39 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/stdio.h" 3
int renameat(int, const char *, int, const char *) ;






int renamex_np(const char *, const char *, unsigned int) ;
int renameatx_np(int, const char *, int, const char *, unsigned int) ;
# 80 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 2 3

typedef __darwin_off_t fpos_t;
# 92 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 3
struct __sbuf {
 unsigned char *_base;
 int _size;
};


struct __sFILEX;
# 126 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_stdio.h" 3
typedef struct __sFILE {
 unsigned char *_p;
 int _r;
 int _w;
 short _flags;
 short _file;
 struct __sbuf _bf;
 int _lbfsize;


 void *_cookie;
 int (* _close)(void *);
 int (* _read) (void *, char *, int);
 fpos_t (* _seek) (void *, fpos_t, int);
 int (* _write)(void *, const char *, int);


 struct __sbuf _ub;
 struct __sFILEX *_extra;
 int _ur;


 unsigned char _ubuf[3];
 unsigned char _nbuf[1];


 struct __sbuf _lb;


 int _blksize;
 fpos_t _offset;
} FILE;
# 65 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 2 3


extern FILE *__stdinp;
extern FILE *__stdoutp;
extern FILE *__stderrp;
# 142 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 3
void clearerr(FILE *);
int fclose(FILE *);
int feof(FILE *);
int ferror(FILE *);
int fflush(FILE *);
int fgetc(FILE *);
int fgetpos(FILE * restrict, fpos_t *);
char *fgets(char * restrict, int, FILE *);



FILE *fopen(const char * restrict __filename, const char * restrict __mode) ;

int fprintf(FILE * restrict, const char * restrict, ...) ;
int fputc(int, FILE *);
int fputs(const char * restrict, FILE * restrict) ;
size_t fread(void * restrict __ptr, size_t __size, size_t __nitems, FILE * restrict __stream);
FILE *freopen(const char * restrict, const char * restrict,
                 FILE * restrict) ;
int fscanf(FILE * restrict, const char * restrict, ...) ;
int fseek(FILE *, long, int);
int fsetpos(FILE *, const fpos_t *);
long ftell(FILE *);
size_t fwrite(const void * restrict __ptr, size_t __size, size_t __nitems, FILE * restrict __stream) ;
int getc(FILE *);
int getchar(void);
char *gets(char *);
void perror(const char *) ;
int printf(const char * restrict, ...) ;
int putc(int, FILE *);
int putchar(int);
int puts(const char *);
int remove(const char *);
int rename (const char *__old, const char *__new);
void rewind(FILE *);
int scanf(const char * restrict, ...) ;
void setbuf(FILE * restrict, char * restrict);
int setvbuf(FILE * restrict, char * restrict, int, size_t);
int sprintf(char * restrict, const char * restrict, ...) ;
int sscanf(const char * restrict, const char * restrict, ...) ;
FILE *tmpfile(void);





char *tmpnam(char *);
int ungetc(int, FILE *);
int vfprintf(FILE * restrict, const char * restrict, va_list) ;
int vprintf(const char * restrict, va_list) ;
int vsprintf(char * restrict, const char * restrict, va_list) ;
# 205 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_ctermid.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_ctermid.h" 3
char *ctermid(char *);
# 206 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 2 3




FILE *fdopen(int, const char *) ;

int fileno(FILE *);
# 228 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 3
int pclose(FILE *) ;



FILE *popen(const char *, const char *) ;
# 249 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 3
int __srget(FILE *);
int __svfscanf(FILE *, const char *, va_list) ;
int __swbuf(int, FILE *);
# 286 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 3
void flockfile(FILE *);
int ftrylockfile(FILE *);
void funlockfile(FILE *);
int getc_unlocked(FILE *);
int getchar_unlocked(void);
int putc_unlocked(int, FILE *);
int putchar_unlocked(int);



int getw(FILE *);
int putw(int, FILE *);






char *tempnam(const char *__dir, const char *__prefix) ;
# 324 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_off_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_off_t.h" 3
typedef __darwin_off_t off_t;
# 325 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 2 3


int fseeko(FILE * __stream, off_t __offset, int __whence);
off_t ftello(FILE * __stream);





int snprintf(char * restrict __str, size_t __size, const char * restrict __format, ...) ;
int vfscanf(FILE * restrict __stream, const char * restrict __format, va_list) ;
int vscanf(const char * restrict __format, va_list) ;
int vsnprintf(char * restrict __str, size_t __size, const char * restrict __format, va_list) ;
int vsscanf(const char * restrict __str, const char * restrict __format, va_list) ;
# 349 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_ssize_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_ssize_t.h" 3
typedef __darwin_ssize_t ssize_t;
# 350 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 2 3


int dprintf(int, const char * restrict, ...) ;
int vdprintf(int, const char * restrict, va_list) ;
ssize_t getdelim(char ** restrict __linep, size_t * restrict __linecapp, int __delimiter, FILE * restrict __stream) ;
ssize_t getline(char ** restrict __linep, size_t * restrict __linecapp, FILE * restrict __stream) ;
FILE *fmemopen(void * restrict __buf, size_t __size, const char * restrict __mode) ;
FILE *open_memstream(char **__bufp, size_t *__sizep) ;
# 367 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdio.h" 3
extern const int sys_nerr;
extern const char *const sys_errlist[];

int asprintf(char ** restrict, const char * restrict, ...) ;
char *ctermid_r(char *);
char *fgetln(FILE *, size_t *);
const char *fmtcheck(const char *, const char *);
int fpurge(FILE *);
void setbuffer(FILE *, char *, int);
int setlinebuf(FILE *);
int vasprintf(char ** restrict, const char * restrict, va_list) ;
FILE *zopen(const char *, const char *, int);





FILE *funopen(const void *,
                 int (* )(void *, char *, int),
                 int (* )(void *, const char *, int),
                 fpos_t (* )(void *, fpos_t, int),
                 int (* )(void *));
# 31 "./genann.h" 2
# 43 "./genann.h"
typedef double (*genann_actfun)(double a);


typedef struct genann {

    int inputs, hidden_layers, hidden, outputs;


    genann_actfun activation_hidden;


    genann_actfun activation_output;


    int total_weights;


    int total_neurons;


    double *weight;


    double *output;


    double *delta;

} genann;




genann *genann_init(int inputs, int hidden_layers, int hidden, int outputs);


genann *genann_read(FILE *in);


void genann_randomize(genann *ann);


genann *genann_copy(genann const *ann);


void genann_free(genann *ann);


double const *genann_run(genann const *ann, double const *inputs);


void genann_train(genann const *ann, double const *inputs, double const *desired_outputs, double learning_rate);


void genann_write(genann const *ann, FILE *out);


double genann_act_sigmoid(double a);
double genann_act_sigmoid_cached(double a);
double genann_act_threshold(double a);
double genann_act_linear(double a);
# 29 "genann.c" 2

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/assert.h" 1 3
# 63 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/assert.h" 3
void abort(void) ;

int printf(const char * restrict, ...);
# 31 "genann.c" 2
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/errno.h" 1 3
# 23 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/errno.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/errno.h" 1 3
# 80 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/errno.h" 3
extern int * __error(void);
# 24 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/errno.h" 2 3
# 32 "genann.c" 2
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 1 3
# 44 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 3
    typedef float float_t;
    typedef double double_t;
# 111 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 3
extern int __math_errhandling(void);
# 131 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 3
extern int __fpclassifyf(float);
extern int __fpclassifyd(double);
extern int __fpclassifyl(long double);
# 284 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 3
extern int __isnormalf(float);
extern int __isnormald(double);
extern int __isnormall(long double);
extern int __isfinitef(float);
extern int __isfinited(double);
extern int __isfinitel(long double);
extern int __isinff(float);
extern int __isinfd(double);
extern int __isinfl(long double);
extern int __isnanf(float);
extern int __isnand(double);
extern int __isnanl(long double);
extern int __signbitf(float);
extern int __signbitd(double);
extern int __signbitl(long double);
# 308 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 3
extern float acosf(float);
extern double acos(double);
extern long double acosl(long double);

extern float asinf(float);
extern double asin(double);
extern long double asinl(long double);

extern float atanf(float);
extern double atan(double);
extern long double atanl(long double);

extern float atan2f(float, float);
extern double atan2(double, double);
extern long double atan2l(long double, long double);

extern float cosf(float);
extern double cos(double);
extern long double cosl(long double);

extern float sinf(float);
extern double sin(double);
extern long double sinl(long double);

extern float tanf(float);
extern double tan(double);
extern long double tanl(long double);

extern float acoshf(float);
extern double acosh(double);
extern long double acoshl(long double);

extern float asinhf(float);
extern double asinh(double);
extern long double asinhl(long double);

extern float atanhf(float);
extern double atanh(double);
extern long double atanhl(long double);

extern float coshf(float);
extern double cosh(double);
extern long double coshl(long double);

extern float sinhf(float);
extern double sinh(double);
extern long double sinhl(long double);

extern float tanhf(float);
extern double tanh(double);
extern long double tanhl(long double);

extern float expf(float);
extern double exp(double);
extern long double expl(long double);

extern float exp2f(float);
extern double exp2(double);
extern long double exp2l(long double);

extern float expm1f(float);
extern double expm1(double);
extern long double expm1l(long double);

extern float logf(float);
extern double log(double);
extern long double logl(long double);

extern float log10f(float);
extern double log10(double);
extern long double log10l(long double);

extern float log2f(float);
extern double log2(double);
extern long double log2l(long double);

extern float log1pf(float);
extern double log1p(double);
extern long double log1pl(long double);

extern float logbf(float);
extern double logb(double);
extern long double logbl(long double);

extern float modff(float, float *);
extern double modf(double, double *);
extern long double modfl(long double, long double *);

extern float ldexpf(float, int);
extern double ldexp(double, int);
extern long double ldexpl(long double, int);

extern float frexpf(float, int *);
extern double frexp(double, int *);
extern long double frexpl(long double, int *);

extern int ilogbf(float);
extern int ilogb(double);
extern int ilogbl(long double);

extern float scalbnf(float, int);
extern double scalbn(double, int);
extern long double scalbnl(long double, int);

extern float scalblnf(float, long int);
extern double scalbln(double, long int);
extern long double scalblnl(long double, long int);

extern float fabsf(float);
extern double fabs(double);
extern long double fabsl(long double);

extern float cbrtf(float);
extern double cbrt(double);
extern long double cbrtl(long double);

extern float hypotf(float, float);
extern double hypot(double, double);
extern long double hypotl(long double, long double);

extern float powf(float, float);
extern double pow(double, double);
extern long double powl(long double, long double);

extern float sqrtf(float);
extern double sqrt(double);
extern long double sqrtl(long double);

extern float erff(float);
extern double erf(double);
extern long double erfl(long double);

extern float erfcf(float);
extern double erfc(double);
extern long double erfcl(long double);




extern float lgammaf(float);
extern double lgamma(double);
extern long double lgammal(long double);

extern float tgammaf(float);
extern double tgamma(double);
extern long double tgammal(long double);

extern float ceilf(float);
extern double ceil(double);
extern long double ceill(long double);

extern float floorf(float);
extern double floor(double);
extern long double floorl(long double);

extern float nearbyintf(float);
extern double nearbyint(double);
extern long double nearbyintl(long double);

extern float rintf(float);
extern double rint(double);
extern long double rintl(long double);

extern long int lrintf(float);
extern long int lrint(double);
extern long int lrintl(long double);

extern float roundf(float);
extern double round(double);
extern long double roundl(long double);

extern long int lroundf(float);
extern long int lround(double);
extern long int lroundl(long double);




extern long long int llrintf(float);
extern long long int llrint(double);
extern long long int llrintl(long double);

extern long long int llroundf(float);
extern long long int llround(double);
extern long long int llroundl(long double);


extern float truncf(float);
extern double trunc(double);
extern long double truncl(long double);

extern float fmodf(float, float);
extern double fmod(double, double);
extern long double fmodl(long double, long double);

extern float remainderf(float, float);
extern double remainder(double, double);
extern long double remainderl(long double, long double);

extern float remquof(float, float, int *);
extern double remquo(double, double, int *);
extern long double remquol(long double, long double, int *);

extern float copysignf(float, float);
extern double copysign(double, double);
extern long double copysignl(long double, long double);

extern float nanf(const char *);
extern double nan(const char *);
extern long double nanl(const char *);

extern float nextafterf(float, float);
extern double nextafter(double, double);
extern long double nextafterl(long double, long double);

extern double nexttoward(double, long double);
extern float nexttowardf(float, long double);
extern long double nexttowardl(long double, long double);

extern float fdimf(float, float);
extern double fdim(double, double);
extern long double fdiml(long double, long double);

extern float fmaxf(float, float);
extern double fmax(double, double);
extern long double fmaxl(long double, long double);

extern float fminf(float, float);
extern double fmin(double, double);
extern long double fminl(long double, long double);

extern float fmaf(float, float, float);
extern double fma(double, double, double);
extern long double fmal(long double, long double, long double);
# 588 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 3
extern float __exp10f(float) ;
extern double __exp10(double) ;





inline void __sincosf(float __x, float *__sinp, float *__cosp);
inline void __sincos(double __x, double *__sinp, double *__cosp);
# 605 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 3
extern float __cospif(float) ;
extern double __cospi(double) ;
extern float __sinpif(float) ;
extern double __sinpi(double) ;
extern float __tanpif(float) ;
extern double __tanpi(double) ;
# 636 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 3
inline void __sincospif(float __x, float *__sinp, float *__cosp);
inline void __sincospi(double __x, double *__sinp, double *__cosp);






struct __float2 { float __sinval; float __cosval; };
struct __double2 { double __sinval; double __cosval; };

extern struct __float2 __sincosf_stret(float);
extern struct __double2 __sincos_stret(double);
extern struct __float2 __sincospif_stret(float);
extern struct __double2 __sincospi_stret(double);

inline void __sincosf(float __x, float *__sinp, float *__cosp) {
    const struct __float2 __stret = __sincosf_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}

inline void __sincos(double __x, double *__sinp, double *__cosp) {
    const struct __double2 __stret = __sincos_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}

inline void __sincospif(float __x, float *__sinp, float *__cosp) {
    const struct __float2 __stret = __sincospif_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}

inline void __sincospi(double __x, double *__sinp, double *__cosp) {
    const struct __double2 __stret = __sincospi_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}







extern double j0(double) ;
extern double j1(double) ;
extern double jn(int, double) ;
extern double y0(double) ;
extern double y1(double) ;
extern double yn(int, double) ;
extern double scalb(double, double);
extern int signgam;
# 763 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/math.h" 3
struct exception {
    int type;
    char *name;
    double arg1;
    double arg2;
    double retval;
};
# 33 "genann.c" 2

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 1 3
# 66 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 1 3
# 79 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 3
typedef enum {
 P_ALL,
 P_PID,
 P_PGID
} idtype_t;





# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_pid_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_pid_t.h" 3
typedef __darwin_pid_t pid_t;
# 90 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_id_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_id_t.h" 3
typedef __darwin_id_t id_t;
# 91 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 2 3
# 109 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 1 3
# 73 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/appleapiopts.h" 1 3
# 74 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 2 3








# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/signal.h" 1 3
# 34 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/signal.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/signal.h" 1 3
# 15 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/signal.h" 3
typedef int sig_atomic_t;
# 35 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/signal.h" 2 3
# 83 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 2 3
# 146 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/_mcontext.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/_mcontext.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/_mcontext.h" 1 3
# 34 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/_mcontext.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/machine/_structs.h" 1 3
# 35 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/machine/_structs.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 1 3
# 39 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __darwin_arm_exception_state
{
 __uint32_t __exception;
 __uint32_t __fsr;
 __uint32_t __far;
};
# 57 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __darwin_arm_exception_state64
{
 __uint64_t __far;
 __uint32_t __esr;
 __uint32_t __exception;
};
# 75 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __darwin_arm_thread_state
{
 __uint32_t __r[13];
 __uint32_t __sp;
 __uint32_t __lr;
 __uint32_t __pc;
 __uint32_t __cpsr;
};
# 134 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __darwin_arm_thread_state64
{
 __uint64_t __x[29];
 __uint64_t __fp;
 __uint64_t __lr;
 __uint64_t __sp;
 __uint64_t __pc;
 __uint32_t __cpsr;
 __uint32_t __pad;
};
# 422 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __darwin_arm_vfp_state
{
 __uint32_t __r[64];
 __uint32_t __fpscr;
};
# 441 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __darwin_arm_neon_state64
{
 __uint128_t __v[32];
 __uint32_t __fpsr;
 __uint32_t __fpcr;
};

struct __darwin_arm_neon_state
{
 __uint128_t __v[16];
 __uint32_t __fpsr;
 __uint32_t __fpcr;
};
# 512 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __darwin_arm_amx_state_v1
{
 __uint8_t __x[8][64];
 __uint8_t __y[8][64];
 __uint8_t __z[64][64];
 __uint64_t __amx_state_t_el1;
} ;
# 531 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __arm_pagein_state
{
 int __pagein_error;
};
# 568 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __arm_legacy_debug_state
{
 __uint32_t __bvr[16];
 __uint32_t __bcr[16];
 __uint32_t __wvr[16];
 __uint32_t __wcr[16];
};
# 591 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __darwin_arm_debug_state32
{
 __uint32_t __bvr[16];
 __uint32_t __bcr[16];
 __uint32_t __wvr[16];
 __uint32_t __wcr[16];
 __uint64_t __mdscr_el1;
};


struct __darwin_arm_debug_state64
{
 __uint64_t __bvr[16];
 __uint64_t __bcr[16];
 __uint64_t __wvr[16];
 __uint64_t __wcr[16];
 __uint64_t __mdscr_el1;
};
# 633 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/arm/_structs.h" 3
struct __darwin_arm_cpmu_state64
{
 __uint64_t __ctrs[16];
};
# 36 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/mach/machine/_structs.h" 2 3
# 35 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/_mcontext.h" 2 3




struct __darwin_mcontext32
{
 struct __darwin_arm_exception_state __es;
 struct __darwin_arm_thread_state __ss;
 struct __darwin_arm_vfp_state __fs;
};
# 62 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/_mcontext.h" 3
struct __darwin_mcontext64
{
 struct __darwin_arm_exception_state64 __es;
 struct __darwin_arm_thread_state64 __ss;
 struct __darwin_arm_neon_state64 __ns;
};
# 83 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/_mcontext.h" 3
typedef struct __darwin_mcontext64 *mcontext_t;
# 32 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/_mcontext.h" 2 3
# 147 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 2 3

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_pthread/_pthread_attr_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_pthread/_pthread_attr_t.h" 3
typedef __darwin_pthread_attr_t pthread_attr_t;
# 149 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 2 3

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_sigaltstack.h" 1 3
# 42 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_sigaltstack.h" 3
struct __darwin_sigaltstack
{
 void *ss_sp;
 __darwin_size_t ss_size;
 int ss_flags;
};
typedef struct __darwin_sigaltstack stack_t;
# 151 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_ucontext.h" 1 3
# 39 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_ucontext.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/_mcontext.h" 1 3
# 40 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_ucontext.h" 2 3



struct __darwin_ucontext
{
 int uc_onstack;
 __darwin_sigset_t uc_sigmask;
 struct __darwin_sigaltstack uc_stack;
 struct __darwin_ucontext *uc_link;
 __darwin_size_t uc_mcsize;
 struct __darwin_mcontext64 *uc_mcontext;



};


typedef struct __darwin_ucontext ucontext_t;
# 152 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 2 3


# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_sigset_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_sigset_t.h" 3
typedef __darwin_sigset_t sigset_t;
# 155 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 2 3

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_uid_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_uid_t.h" 3
typedef __darwin_uid_t uid_t;
# 157 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 2 3

union sigval {

 int sival_int;
 void *sival_ptr;
};





struct sigevent {
 int sigev_notify;
 int sigev_signo;
 union sigval sigev_value;
 void (*sigev_notify_function)(union sigval);
 pthread_attr_t *sigev_notify_attributes;
};


typedef struct __siginfo {
 int si_signo;
 int si_errno;
 int si_code;
 pid_t si_pid;
 uid_t si_uid;
 int si_status;
 void *si_addr;
 union sigval si_value;
 long si_band;
 unsigned long __pad[7];
} siginfo_t;
# 269 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 3
union __sigaction_u {
 void (*__sa_handler)(int);
 void (*__sa_sigaction)(int, struct __siginfo *,
     void *);
};


struct __sigaction {
 union __sigaction_u __sigaction_u;
 void (*sa_tramp)(void *, int, int, siginfo_t *, void *);
 sigset_t sa_mask;
 int sa_flags;
};




struct sigaction {
 union __sigaction_u __sigaction_u;
 sigset_t sa_mask;
 int sa_flags;
};
# 331 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 3
typedef void (*sig_t)(int);
# 348 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 3
struct sigvec {
 void (*sv_handler)(int);
 int sv_mask;
 int sv_flags;
};
# 367 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 3
struct sigstack {
 char *ss_sp;
 int ss_onstack;
};
# 390 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/signal.h" 3
    void(*signal(int, void (*)(int)))(int);
# 110 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 1 3
# 72 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 3
# 1 "/nix/store/6kpjydf9x7zqa1xq2qipnwr32ki3fs2n-clang-wrapper-16.0.6/resource-root/include/stdint.h" 1 3
# 52 "/nix/store/6kpjydf9x7zqa1xq2qipnwr32ki3fs2n-clang-wrapper-16.0.6/resource-root/include/stdint.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdint.h" 1 3
# 23 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdint.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uint8_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uint8_t.h" 3
typedef unsigned char uint8_t;
# 24 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdint.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uint16_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uint16_t.h" 3
typedef unsigned short uint16_t;
# 25 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdint.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uint32_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uint32_t.h" 3
typedef unsigned int uint32_t;
# 26 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdint.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uint64_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uint64_t.h" 3
typedef unsigned long long uint64_t;
# 27 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdint.h" 2 3


typedef int8_t int_least8_t;
typedef int16_t int_least16_t;
typedef int32_t int_least32_t;
typedef int64_t int_least64_t;
typedef uint8_t uint_least8_t;
typedef uint16_t uint_least16_t;
typedef uint32_t uint_least32_t;
typedef uint64_t uint_least64_t;



typedef int8_t int_fast8_t;
typedef int16_t int_fast16_t;
typedef int32_t int_fast32_t;
typedef int64_t int_fast64_t;
typedef uint8_t uint_fast8_t;
typedef uint16_t uint_fast16_t;
typedef uint32_t uint_fast32_t;
typedef uint64_t uint_fast64_t;
# 58 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdint.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_intmax_t.h" 1 3
# 32 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_intmax_t.h" 3
typedef long int intmax_t;
# 59 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdint.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uintmax_t.h" 1 3
# 32 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/_types/_uintmax_t.h" 3
typedef long unsigned int uintmax_t;
# 60 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdint.h" 2 3
# 53 "/nix/store/6kpjydf9x7zqa1xq2qipnwr32ki3fs2n-clang-wrapper-16.0.6/resource-root/include/stdint.h" 2 3
# 73 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 2 3







# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_timeval.h" 1 3
# 34 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_timeval.h" 3
struct timeval
{
 __darwin_time_t tv_sec;
 __darwin_suseconds_t tv_usec;
};
# 81 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 2 3








typedef __uint64_t rlim_t;
# 152 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 3
struct rusage {
 struct timeval ru_utime;
 struct timeval ru_stime;
# 163 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 3
 long ru_maxrss;

 long ru_ixrss;
 long ru_idrss;
 long ru_isrss;
 long ru_minflt;
 long ru_majflt;
 long ru_nswap;
 long ru_inblock;
 long ru_oublock;
 long ru_msgsnd;
 long ru_msgrcv;
 long ru_nsignals;
 long ru_nvcsw;
 long ru_nivcsw;


};
# 199 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 3
typedef void *rusage_info_t;

struct rusage_info_v0 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
};

struct rusage_info_v1 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
};

struct rusage_info_v2 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
 uint64_t ri_diskio_bytesread;
 uint64_t ri_diskio_byteswritten;
};

struct rusage_info_v3 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
 uint64_t ri_diskio_bytesread;
 uint64_t ri_diskio_byteswritten;
 uint64_t ri_cpu_time_qos_default;
 uint64_t ri_cpu_time_qos_maintenance;
 uint64_t ri_cpu_time_qos_background;
 uint64_t ri_cpu_time_qos_utility;
 uint64_t ri_cpu_time_qos_legacy;
 uint64_t ri_cpu_time_qos_user_initiated;
 uint64_t ri_cpu_time_qos_user_interactive;
 uint64_t ri_billed_system_time;
 uint64_t ri_serviced_system_time;
};

struct rusage_info_v4 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
 uint64_t ri_diskio_bytesread;
 uint64_t ri_diskio_byteswritten;
 uint64_t ri_cpu_time_qos_default;
 uint64_t ri_cpu_time_qos_maintenance;
 uint64_t ri_cpu_time_qos_background;
 uint64_t ri_cpu_time_qos_utility;
 uint64_t ri_cpu_time_qos_legacy;
 uint64_t ri_cpu_time_qos_user_initiated;
 uint64_t ri_cpu_time_qos_user_interactive;
 uint64_t ri_billed_system_time;
 uint64_t ri_serviced_system_time;
 uint64_t ri_logical_writes;
 uint64_t ri_lifetime_max_phys_footprint;
 uint64_t ri_instructions;
 uint64_t ri_cycles;
 uint64_t ri_billed_energy;
 uint64_t ri_serviced_energy;
 uint64_t ri_interval_max_phys_footprint;
 uint64_t ri_runnable_time;
};

struct rusage_info_v5 {
 uint8_t ri_uuid[16];
 uint64_t ri_user_time;
 uint64_t ri_system_time;
 uint64_t ri_pkg_idle_wkups;
 uint64_t ri_interrupt_wkups;
 uint64_t ri_pageins;
 uint64_t ri_wired_size;
 uint64_t ri_resident_size;
 uint64_t ri_phys_footprint;
 uint64_t ri_proc_start_abstime;
 uint64_t ri_proc_exit_abstime;
 uint64_t ri_child_user_time;
 uint64_t ri_child_system_time;
 uint64_t ri_child_pkg_idle_wkups;
 uint64_t ri_child_interrupt_wkups;
 uint64_t ri_child_pageins;
 uint64_t ri_child_elapsed_abstime;
 uint64_t ri_diskio_bytesread;
 uint64_t ri_diskio_byteswritten;
 uint64_t ri_cpu_time_qos_default;
 uint64_t ri_cpu_time_qos_maintenance;
 uint64_t ri_cpu_time_qos_background;
 uint64_t ri_cpu_time_qos_utility;
 uint64_t ri_cpu_time_qos_legacy;
 uint64_t ri_cpu_time_qos_user_initiated;
 uint64_t ri_cpu_time_qos_user_interactive;
 uint64_t ri_billed_system_time;
 uint64_t ri_serviced_system_time;
 uint64_t ri_logical_writes;
 uint64_t ri_lifetime_max_phys_footprint;
 uint64_t ri_instructions;
 uint64_t ri_cycles;
 uint64_t ri_billed_energy;
 uint64_t ri_serviced_energy;
 uint64_t ri_interval_max_phys_footprint;
 uint64_t ri_runnable_time;
 uint64_t ri_flags;
};

typedef struct rusage_info_v5 rusage_info_current;
# 411 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 3
struct rlimit {
 rlim_t rlim_cur;
 rlim_t rlim_max;
};
# 446 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 3
struct proc_rlimit_control_wakeupmon {
 uint32_t wm_flags;
 int32_t wm_rate;
};
# 499 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/resource.h" 3
int getpriority(int, id_t);

int getiopolicy_np(int, int) ;

int getrlimit(int, struct rlimit *) ;
int getrusage(int, struct rusage *);
int setpriority(int, id_t, int);

int setiopolicy_np(int, int, int) ;

int setrlimit(int, const struct rlimit *) ;
# 111 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 2 3
# 186 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/endian.h" 1 3
# 37 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/endian.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/endian.h" 1 3
# 75 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/endian.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_endian.h" 1 3
# 130 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_endian.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/libkern/_OSByteOrder.h" 1 3
# 131 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_endian.h" 2 3
# 76 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/arm/endian.h" 2 3
# 38 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/machine/endian.h" 2 3
# 187 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 2 3







union wait {
 int w_status;



 struct {

  unsigned int w_Termsig:7,
      w_Coredump:1,
      w_Retcode:8,
      w_Filler:16;







 } w_T;





 struct {

  unsigned int w_Stopval:8,
      w_Stopsig:8,
      w_Filler:16;






 } w_S;
};
# 248 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/wait.h" 3
pid_t wait(int *) ;
pid_t waitpid(pid_t, int *, int) ;

int waitid(idtype_t, id_t, siginfo_t *, int) ;


pid_t wait3(int *, int, struct rusage *);
pid_t wait4(pid_t, int *, int, struct rusage *);
# 67 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 2 3

# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/alloca.h" 1 3
# 32 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/alloca.h" 3
void *alloca(size_t);
# 69 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 2 3








# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_ct_rune_t.h" 1 3
# 32 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_ct_rune_t.h" 3
typedef __darwin_ct_rune_t ct_rune_t;
# 78 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_rune_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_rune_t.h" 3
typedef __darwin_rune_t rune_t;
# 79 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 2 3


# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_wchar_t.h" 1 3
# 34 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_wchar_t.h" 3
typedef __darwin_wchar_t wchar_t;
# 82 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 2 3

typedef struct {
 int quot;
 int rem;
} div_t;

typedef struct {
 long quot;
 long rem;
} ldiv_t;


typedef struct {
 long long quot;
 long long rem;
} lldiv_t;
# 118 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 3
extern int __mb_cur_max;
# 128 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/malloc/_malloc.h" 1 3
# 40 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/malloc/_malloc.h" 3
void *malloc(size_t __size) ;
void *calloc(size_t __count, size_t __size) ;
void free(void *);
void *realloc(void *__ptr, size_t __size) ;

void *valloc(size_t) ;




void *aligned_alloc(size_t __alignment, size_t __size) ;

int posix_memalign(void **__memptr, size_t __alignment, size_t __size) ;
# 129 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 2 3


void abort(void) ;
int abs(int) ;
int atexit(void (* )(void));
double atof(const char *);
int atoi(const char *);
long atol(const char *);

long long
  atoll(const char *);

void *bsearch(const void *__key, const void *__base, size_t __nel,
     size_t __width, int (* __compar)(const void *, const void *));

div_t div(int, int) ;
void exit(int) ;

char *getenv(const char *);
long labs(long) ;
ldiv_t ldiv(long, long) ;

long long
  llabs(long long);
lldiv_t lldiv(long long, long long);


int mblen(const char *__s, size_t __n);
size_t mbstowcs(wchar_t * restrict , const char * restrict, size_t);
int mbtowc(wchar_t * restrict, const char * restrict, size_t);

void qsort(void *__base, size_t __nel, size_t __width,
     int (* __compar)(const void *, const void *));
int rand(void) ;

void srand(unsigned) ;
double strtod(const char *, char **) ;
float strtof(const char *, char **) ;
long strtol(const char *__str, char **__endptr, int __base);
long double
  strtold(const char *, char **);

long long
  strtoll(const char *__str, char **__endptr, int __base);

unsigned long
  strtoul(const char *__str, char **__endptr, int __base);

unsigned long long
  strtoull(const char *__str, char **__endptr, int __base);
# 190 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 3
int system(const char *) ;



size_t wcstombs(char * restrict, const wchar_t * restrict, size_t);
int wctomb(char *, wchar_t);


void _Exit(int) ;
long a64l(const char *);
double drand48(void);
char *ecvt(double, int, int *restrict, int *restrict);
double erand48(unsigned short[3]);
char *fcvt(double, int, int *restrict, int *restrict);
char *gcvt(double, int, char *);
int getsubopt(char **, char * const *, char **);
int grantpt(int);

char *initstate(unsigned, char *, size_t);



long jrand48(unsigned short[3]) ;
char *l64a(long);
void lcong48(unsigned short[7]);
long lrand48(void) ;
char *mktemp(char *);
int mkstemp(char *);
long mrand48(void) ;
long nrand48(unsigned short[3]) ;
int posix_openpt(int);
char *ptsname(int);


int ptsname_r(int fildes, char *buffer, size_t buflen) ;


int putenv(char *) ;
long random(void) ;
int rand_r(unsigned *) ;

char *realpath(const char * restrict, char * restrict) ;



unsigned short
 *seed48(unsigned short[3]);
int setenv(const char * __name, const char * __value, int __overwrite) ;

void setkey(const char *) ;



char *setstate(const char *);
void srand48(long);

void srandom(unsigned);



int unlockpt(int);

int unsetenv(const char *) ;







# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_dev_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_dev_t.h" 3
typedef __darwin_dev_t dev_t;
# 261 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 2 3
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_mode_t.h" 1 3
# 31 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/sys/_types/_mode_t.h" 3
typedef __darwin_mode_t mode_t;
# 262 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 2 3


uint32_t arc4random(void);
void arc4random_addrandom(unsigned char * , int )



                                                         ;
void arc4random_buf(void * __buf, size_t __nbytes) ;
void arc4random_stir(void);
uint32_t
  arc4random_uniform(uint32_t __upper_bound) ;







char *cgetcap(char *, const char *, int);
int cgetclose(void);
int cgetent(char **, char **, const char *);
int cgetfirst(char **, char **);
int cgetmatch(const char *, const char *);
int cgetnext(char **, char **);
int cgetnum(char *, const char *, long *);
int cgetset(const char *);
int cgetstr(char *, const char *, char **);
int cgetustr(char *, const char *, char **);

int daemon(int, int) ;
char *devname(dev_t, mode_t);
char *devname_r(dev_t, mode_t, char *buf, int len);
char *getbsize(int *, long *);
int getloadavg(double [], int);
const char
 *getprogname(void);
void setprogname(const char *);
# 309 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/stdlib.h" 3
int heapsort(void *__base, size_t __nel, size_t __width,
     int (* __compar)(const void *, const void *));





int mergesort(void *__base, size_t __nel, size_t __width,
     int (* __compar)(const void *, const void *));





void psort(void *__base, size_t __nel, size_t __width,
     int (* __compar)(const void *, const void *))
                                                       ;





void psort_r(void *__base, size_t __nel, size_t __width, void *,
     int (* __compar)(void *, const void *, const void *))
                                                       ;





void qsort_r(void *__base, size_t __nel, size_t __width, void *,
     int (* __compar)(void *, const void *, const void *));
int radixsort(const unsigned char **__base, int __nel, const unsigned char *__table,
     unsigned __endbyte);
int rpmatch(const char *)
                                                                   ;
int sradixsort(const unsigned char **__base, int __nel, const unsigned char *__table,
     unsigned __endbyte);
void sranddev(void);
void srandomdev(void);
void *reallocf(void *__ptr, size_t __size) ;
long long
 strtonum(const char *__numstr, long long __minval, long long __maxval, const char **__errstrp)
                                                                  ;

long long
  strtoq(const char *__str, char **__endptr, int __base);
unsigned long long
  strtouq(const char *__str, char **__endptr, int __base);

extern char *suboptarg;
# 35 "genann.c" 2
# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/string.h" 1 3
# 70 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/string.h" 3
void *memchr(const void *__s, int __c, size_t __n);
int memcmp(const void *__s1, const void *__s2, size_t __n);
void *memcpy(void *__dst, const void *__src, size_t __n);
void *memmove(void *__dst, const void *__src, size_t __len);
void *memset(void *__b, int __c, size_t __len);
char *strcat(char *__s1, const char *__s2);
char *strchr(const char *__s, int __c);
int strcmp(const char *__s1, const char *__s2);
int strcoll(const char *__s1, const char *__s2);
char *strcpy(char *__dst, const char *__src);
size_t strcspn(const char *__s, const char *__charset);
char *strerror(int __errnum) ;
size_t strlen(const char *__s);
char *strncat(char *__s1, const char *__s2, size_t __n);
int strncmp(const char *__s1, const char *__s2, size_t __n);
char *strncpy(char *__dst, const char *__src, size_t __n);
char *strpbrk(const char *__s, const char *__charset);
char *strrchr(const char *__s, int __c);
size_t strspn(const char *__s, const char *__charset);
char *strstr(const char *__big, const char *__little);
char *strtok(char *__str, const char *__sep);
size_t strxfrm(char *__s1, const char *__s2, size_t __n);
# 104 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/string.h" 3
char *strtok_r(char *__str, const char *__sep, char **__lasts);
# 116 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/string.h" 3
int strerror_r(int __errnum, char *__strerrbuf, size_t __buflen);
char *strdup(const char *__s1);
void *memccpy(void *__dst, const void *__src, int __c, size_t __n);
# 130 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/string.h" 3
char *stpcpy(char *__dst, const char *__src);
char *stpncpy(char *__dst, const char *__src, size_t __n) ;
char *strndup(const char *__s1, size_t __n) ;
size_t strnlen(const char *__s1, size_t __n) ;
char *strsignal(int __sig);
# 155 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/string.h" 3
void *memmem(const void *__big, size_t __big_len, const void *__little, size_t __little_len) ;
void memset_pattern4(void *__b, const void *__pattern4, size_t __len) ;
void memset_pattern8(void *__b, const void *__pattern8, size_t __len) ;
void memset_pattern16(void *__b, const void *__pattern16, size_t __len) ;

char *strcasestr(const char *__big, const char *__little);
char *strnstr(const char *__big, const char *__little, size_t __len);
size_t strlcat(char *__dst, const char *__source, size_t __size);
size_t strlcpy(char *__dst, const char *__source, size_t __size);
void strmode(int __mode, char *__bp);
char *strsep(char **__stringp, const char *__delim);


void swab(const void * restrict, void * restrict, ssize_t);



int timingsafe_bcmp(const void *__b1, const void *__b2, size_t __len);



int strsignal_r(int __sig, char *__strsignalbuf, size_t __buflen);







# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/strings.h" 1 3
# 70 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/strings.h" 3
int bcmp(const void *, const void *, size_t) ;
void bcopy(const void *, void *, size_t) ;
void bzero(void *, size_t) ;
char *index(const char *, int) ;
char *rindex(const char *, int) ;


int ffs(int);
int strcasecmp(const char *, const char *);
int strncasecmp(const char *, const char *, size_t);





int ffsl(long) ;
int ffsll(long long) ;
int fls(int) ;
int flsl(long) ;
int flsll(long long) ;


# 1 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/string.h" 1 3
# 93 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/strings.h" 2 3
# 185 "/nix/store/2cgdzzb6wy0jnnzsqrq93lw7bzxr9w8h-libSystem-11.0.0/include/string.h" 2 3
# 36 "genann.c" 2



double genann_act_sigmoid(double a) {
    if (a < -45.0) return 0;
    if (a > 45.0) return 1;
    return 1.0 / (1 + exp(-a));
}


double genann_act_sigmoid_cached(double a) {




    const double min = -15.0;
    const double max = 15.0;
    static double interval;
    static int initialized = 0;
    static double lookup[4096];


    if (!initialized) {
        interval = (max - min) / 4096;
        int i;
        for (i = 0; i < 4096; ++i) {
            lookup[i] = genann_act_sigmoid(min + interval * i);
        }

        initialized = 1;
    }

    int i;
    i = (int)((a-min)/interval+0.5);
    if (i <= 0) return lookup[0];
    if (i >= 4096) return lookup[4096 -1];
    return lookup[i];
}


double genann_act_threshold(double a) {
    return a > 0;
}


double genann_act_linear(double a) {
    return a;
}


genann *genann_init(int inputs, int hidden_layers, int hidden, int outputs) {
    if (hidden_layers < 0) return 0;
    if (inputs < 1) return 0;
    if (outputs < 1) return 0;
    if (hidden_layers > 0 && hidden < 1) return 0;


    const int hidden_weights = hidden_layers ? (inputs+1) * hidden + (hidden_layers-1) * (hidden+1) * hidden : 0;
    const int output_weights = (hidden_layers ? (hidden+1) : (inputs+1)) * outputs;
    const int total_weights = (hidden_weights + output_weights);

    const int total_neurons = (inputs + hidden * hidden_layers + outputs);


    const int size = sizeof(genann) + sizeof(double) * (total_weights + total_neurons + (total_neurons - inputs));
    genann *ret = malloc(size);
    if (!ret) return 0;

    ret->inputs = inputs;
    ret->hidden_layers = hidden_layers;
    ret->hidden = hidden;
    ret->outputs = outputs;

    ret->total_weights = total_weights;
    ret->total_neurons = total_neurons;


    ret->weight = (double*)((char*)ret + sizeof(genann));
    ret->output = ret->weight + ret->total_weights;
    ret->delta = ret->output + ret->total_neurons;

    genann_randomize(ret);

    ret->activation_hidden = genann_act_sigmoid_cached;
    ret->activation_output = genann_act_sigmoid_cached;

    return ret;
}


genann *genann_read(FILE *in) {
    int inputs, hidden_layers, hidden, outputs;
    int rc;

    (*__error()) = 0;
    rc = fscanf(in, "%d %d %d %d", &inputs, &hidden_layers, &hidden, &outputs);
    if (rc < 4 || (*__error()) != 0) {
        perror("fscanf");
        return ((void *)0);
    }

    genann *ann = genann_init(inputs, hidden_layers, hidden, outputs);

    int i;
    for (i = 0; i < ann->total_weights; ++i) {
        (*__error()) = 0;
        rc = fscanf(in, " %le", ann->weight + i);
        if (rc < 1 || (*__error()) != 0) {
            perror("fscanf");
            genann_free(ann);

            return ((void *)0);
        }
    }

    return ann;
}


genann *genann_copy(genann const *ann) {
    const int size = sizeof(genann) + sizeof(double) * (ann->total_weights + ann->total_neurons + (ann->total_neurons - ann->inputs));
    genann *ret = malloc(size);
    if (!ret) return 0;

    memcpy(ret, ann, size);


    ret->weight = (double*)((char*)ret + sizeof(genann));
    ret->output = ret->weight + ret->total_weights;
    ret->delta = ret->output + ret->total_neurons;

    return ret;
}


void genann_randomize(genann *ann) {
    int i;
    for (i = 0; i < ann->total_weights; ++i) {
        double r = (((double)rand())/0x7fffffff);

        ann->weight[i] = r - 0.5;
    }
}


void genann_free(genann *ann) {

    free(ann);
}


double const *genann_run(genann const *ann, double const *inputs) {
    double const *w = ann->weight;
    double *o = ann->output + ann->inputs;
    double const *i = ann->output;



    memcpy(ann->output, inputs, sizeof(double) * ann->inputs);

    int h, j, k;

    const genann_actfun act = ann->activation_hidden;
    const genann_actfun acto = ann->activation_output;


    for (h = 0; h < ann->hidden_layers; ++h) {
        for (j = 0; j < ann->hidden; ++j) {
            double sum = *w++ * -1.0;
            for (k = 0; k < (h == 0 ? ann->inputs : ann->hidden); ++k) {
                sum += *w++ * i[k];
            }
            *o++ = act(sum);
        }


        i += (h == 0 ? ann->inputs : ann->hidden);
    }

    double const *ret = o;


    for (j = 0; j < ann->outputs; ++j) {
        double sum = *w++ * -1.0;
        for (k = 0; k < (ann->hidden_layers ? ann->hidden : ann->inputs); ++k) {
            sum += *w++ * i[k];
        }
        *o++ = acto(sum);
    }


    ((void) ((w - ann->weight == ann->total_weights) ? ((void)0) : ((void)printf ("%s:%d: failed assertion `%s'\n", "genann.c", 227, "w - ann->weight == ann->total_weights"), abort())));
    ((void) ((o - ann->output == ann->total_neurons) ? ((void)0) : ((void)printf ("%s:%d: failed assertion `%s'\n", "genann.c", 228, "o - ann->output == ann->total_neurons"), abort())));

    return ret;
}


void genann_train(genann const *ann, double const *inputs, double const *desired_outputs, double learning_rate) {

    printf("%p PTR %d", &genann_run, 420);
    genann_run(ann, inputs);

    int h, j, k;


    {
        double const *o = ann->output + ann->inputs + ann->hidden * ann->hidden_layers;
        double *d = ann->delta + ann->hidden * ann->hidden_layers;
        double const *t = desired_outputs;



        if (ann->activation_output == genann_act_linear) {
            for (j = 0; j < ann->outputs; ++j) {
                *d++ = *t++ - *o++;
            }
        } else {
            for (j = 0; j < ann->outputs; ++j) {
                *d++ = (*t - *o) * *o * (1.0 - *o);
                ++o; ++t;
            }
        }
    }




    for (h = ann->hidden_layers - 1; h >= 0; --h) {


        double const *o = ann->output + ann->inputs + (h * ann->hidden);
        double *d = ann->delta + (h * ann->hidden);


        double const * const dd = ann->delta + ((h+1) * ann->hidden);


        double const * const ww = ann->weight + ((ann->inputs+1) * ann->hidden) + ((ann->hidden+1) * ann->hidden * (h));

        for (j = 0; j < ann->hidden; ++j) {

            double delta = 0;

            for (k = 0; k < (h == ann->hidden_layers-1 ? ann->outputs : ann->hidden); ++k) {
                const double forward_delta = dd[k];
                const int windex = k * (ann->hidden + 1) + (j + 1);
                const double forward_weight = ww[windex];
                delta += forward_delta * forward_weight;
            }

            *d = *o * (1.0-*o) * delta;
            ++d; ++o;
        }
    }



    {

        double const *d = ann->delta + ann->hidden * ann->hidden_layers;


        double *w = ann->weight + (ann->hidden_layers
                ? ((ann->inputs+1) * ann->hidden + (ann->hidden+1) * ann->hidden * (ann->hidden_layers-1))
                : (0));


        double const * const i = ann->output + (ann->hidden_layers
                ? (ann->inputs + (ann->hidden) * (ann->hidden_layers-1))
                : 0);


        for (j = 0; j < ann->outputs; ++j) {
            for (k = 0; k < (ann->hidden_layers ? ann->hidden : ann->inputs) + 1; ++k) {
                if (k == 0) {
                    *w++ += *d * learning_rate * -1.0;
                } else {
                    *w++ += *d * learning_rate * i[k-1];
                }
            }

            ++d;
        }

        ((void) ((w - ann->weight == ann->total_weights) ? ((void)0) : ((void)printf ("%s:%d: failed assertion `%s'\n", "genann.c", 321, "w - ann->weight == ann->total_weights"), abort())));
    }



    for (h = ann->hidden_layers - 1; h >= 0; --h) {


        double const *d = ann->delta + (h * ann->hidden);


        double const *i = ann->output + (h
                ? (ann->inputs + ann->hidden * (h-1))
                : 0);


        double *w = ann->weight + (h
                ? ((ann->inputs+1) * ann->hidden + (ann->hidden+1) * (ann->hidden) * (h-1))
                : 0);


        for (j = 0; j < ann->hidden; ++j) {
            for (k = 0; k < (h == 0 ? ann->inputs : ann->hidden) + 1; ++k) {
                if (k == 0) {
                    *w++ += *d * learning_rate * -1.0;
                } else {
                    *w++ += *d * learning_rate * i[k-1];
                }
            }
            ++d;
        }

    }

}


void genann_write(genann const *ann, FILE *out) {
    fprintf(out, "%d %d %d %d", ann->inputs, ann->hidden_layers, ann->hidden, ann->outputs);

    int i;
    for (i = 0; i < ann->total_weights; ++i) {
        fprintf(out, " %.20e", ann->weight[i]);
    }
}
