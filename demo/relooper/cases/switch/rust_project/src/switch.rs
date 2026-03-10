
unsafe extern "C" {

  
}

unsafe extern "C" {

  
}

#[unsafe(no_mangle)]
pub extern "C" fn switch_val(mut val : core::ffi::c_int) -> core::ffi::c_int {
  unsafe {
    
    match val {
      1 => {
        
        return (2 as core::ffi::c_int);
      }
      2 => {
        
        return (4 as core::ffi::c_int);
      }
      _ => {
        
        
        return (val + (1 as core::ffi::c_int));
      }
      
    };
  }
}


