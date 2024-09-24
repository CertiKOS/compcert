static mut __stringlit_1 : [ libc::c_schar; 16] = ;

#[no_mangle]
unsafe extern "C" fn sum(count : libc::c_int, ) -> libc::c_int
{
  let mut args : unimplemented!;
  let mut result : libc::c_int;
  let mut i : libc::c_int;
  let mut tmp_id_63 : libc::c_uint;
  result = 0;
  
  __builtin_va_start(unimplemented addrof);
  i = 0;
  
  unimplemented?!
  return result;
  
}

#[no_mangle]
unsafe extern "C" fn main() -> libc::c_int
{
  let mut result : libc::c_int;
  let mut tmp_id_63 : libc::c_int;
  tmp_id_63 = sum(5, 1, 2, 3, 4, 5);
  result = tmp_id_63;
  
  printf(__stringlit_1, result);
  return 0;
  
  return 0;
  
}


