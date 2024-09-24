#[no_mangle]
unsafe extern "C" fn main() -> libc::c_int
{
  let mut a : [ libc::c_int; 3];
  let mut address_of_sum : *mut libc::c_int;
  let mut address_of_sum_2 : *mut libc::c_int;
  (*(a + (0 as libc::c_int))) = (10 as libc::c_int);
  
  (*(a + (1 as libc::c_int))) = (5 as libc::c_int);
  
  (*(a + (2 as libc::c_int))) = (3 as libc::c_int);
  
  address_of_sum = a;
  
  address_of_sum_2 = (a + (1 as libc::c_int));
  
  return (0 as libc::c_int);
  
}


