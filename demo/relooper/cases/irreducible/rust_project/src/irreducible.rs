
unsafe extern "C" {

  
}

unsafe extern "C" {

  
}

#[unsafe(no_mangle)]
pub extern "C" fn irreducible(mut x : core::ffi::c_int) -> core::ffi::c_int {
  unsafe {
    'lbl_127: loop {
      'lbl_143: {
        'lbl_133: {
          
          
          if (((x < (6 as core::ffi::c_int)) as core::ffi::c_int) != (0 as core::ffi::c_int)) {
            
            x = (x + (1 as core::ffi::c_int));
            
            
            if (((x < (20 as core::ffi::c_int)) as core::ffi::c_int) != (0 as core::ffi::c_int)) {
              
              x = (x + (90 as core::ffi::c_int));
            } else {
              break 'lbl_143;
            }
          } else {
            
          }
        }
        'lbl_133: loop {
          
          
          if (((x < (9 as core::ffi::c_int)) as core::ffi::c_int) != (0 as core::ffi::c_int)) {
            
            x = (x + (2 as core::ffi::c_int));
            continue 'lbl_127;
          } else {
            
            
            
            if (((x < (20 as core::ffi::c_int)) as core::ffi::c_int) != (0 as core::ffi::c_int)) {
              
              x = (x + (90 as core::ffi::c_int));
            } else {
              break 'lbl_143;
            }
          }
        }
      }
      
      
      return x;
    }
  }
}


