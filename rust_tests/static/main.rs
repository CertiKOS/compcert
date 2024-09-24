static mut a : libc::c_int = 9;

static mut a__1 : libc::c_int = 0;

#[no_mangle]
unsafe extern "C" fn example() -> libc::c_int
{
  a__1 = (a__1 + (1 as libc::c_int));
  
  return a__1;
  
}

#[no_mangle]
unsafe extern "C" fn example_2() -> libc::c_int
{
  a = (a + (1 as libc::c_int));
  
}

#[no_mangle]
unsafe extern "C" fn main() -> libc::c_int
{
  return (0 as libc::c_int);
  
}


