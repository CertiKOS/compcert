#[repr(C, align(16))]
union MyUnion {
   a : libc::c_schar,
   b : libc::c_int,
   c : libc::c_double,
}
 
#[repr(C, align(8))]
struct MyStruct {
   c : libc::c_schar,
   i : libc::c_int,
}
 
#[repr(C)]
struct MyStruct2 {
   a : libc::c_schar,
   b : libc::c_int,
   c : libc::c_schar,
}
 
#[no_mangle]
unsafe extern "C" fn main() -> libc::c_int
{
  let mut a : [ libc::c_int; 4];
  let mut s : MyStruct;
  let mut s2 : MyStruct2;
  let mut myunion : MyUnion;
  let mut c : libc::c_int;
  let mut b : libc::c_int;
  s.c = 65 as libc::c_int;
  
  s.i = 42 as libc::c_int;
  
  s2.a = 65 as libc::c_int;
  
  s2.b = 42 as libc::c_int;
  
  s2.c = 67 as libc::c_int;
  
  c = (std::mem::alignof::<MyStruct>() as libc::c_ulonglong);
  
  b = (std::mem::sizeof::<MyStruct>() as libc::c_ulonglong);
  
  return 0 as libc::c_int;
  
  return 0 as libc::c_int;
  
}


