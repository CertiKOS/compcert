#[repr(C)]
struct ExampleStruct {
   a : libc::c_int,
   b : libc::c_float,
   c : libc::c_schar,
}
 
#[repr(C)]
union ExampleUnion {
   i : libc::c_int,
   f : libc::c_float,
   c : libc::c_schar,
}
 
#[no_mangle]
unsafe extern "C" fn main() -> libc::c_int
{
  let mut example_struct : ExampleStruct;
  let mut example_union : ExampleUnion;
  example_struct.a = (1 as libc::c_int);
  
  example_struct.b = (0 as libc::c_double);
  
  example_struct.c = (0 as libc::c_int);
  
  example_struct.a = (42 as libc::c_int);
  
  example_struct.b = (42 as libc::c_float);
  
  example_struct.b = (102 as libc::c_int);
  
  example_union.i = (42 as libc::c_int);
  
  return (0 as libc::c_int);
  
}


