#[no_mangle]
unsafe extern "C" fn main() -> libc::c_int
{
  'lbl_0: loop {
    /* skip stmt */
    
    if ((1 as libc::c_int) == (2 as libc::c_int)) {
      break 'lbl_0; 
      
    } else {
      continue 'lbl_0;
    }
    
  }
  
  return (0 as libc::c_int);
  
  return (0 as libc::c_int);
  
}

#[no_mangle]
unsafe extern "C" fn aux() -> libc::c_int
{
  let mut i : libc::c_int;
  i = (0 as libc::c_int);
  
  'lbl_0: loop {
    if !((i < (10 as libc::c_int))) {
      break 'lbl_0; 
      
    }
    
    if (i == (i + (1 as libc::c_int))) {
      break 'lbl_0; 
      
    } else {
      continue 'lbl_0;
    }
    
    i = (i + (1 as libc::c_int));
    
  }
  
  return (0 as libc::c_int);
  
}

#[no_mangle]
unsafe extern "C" fn aux_2() -> libc::c_int
{
  'lbl_0: loop {
    if ((1 as libc::c_int) == (2 as libc::c_int)) {
      break 'lbl_0; 
      
    } else {
      continue 'lbl_0;
    }
    
    if !(((1 as libc::c_int) == (2 as libc::c_int))) {
      break 'lbl_0; 
      
    }
    
  }
  
  return (0 as libc::c_int);
  
}


