#[no_mangle]
unsafe extern "C" fn switch_ex(e : libc::c_int, ) -> libc::c_int
{
  let mut a : libc::c_int;
  let mut tmp_id_60 : libc::c_int;
  let mut tmp_id_59 : bool;
  a = (9 as libc::c_int);
  
  tmp_id_59 = false;
  
  tmp_id_60 = e;
  
  'lbl_0: loop {
    if tmp_id_59 {
      a = (a + (2 as libc::c_int));
      
      tmp_id_60 = (3 as libc::c_int);
      
      tmp_id_59 = false;
      
    }
    
    match tmp_id_60 {
      4 => {
        a = (10 as libc::c_int);
        
        break 'lbl_0; 
        
      }
      3 => {
        a = (a - (2 as libc::c_int));
        
        tmp_id_60 = (4 as libc::c_int);
        
      }
      5 => {
        a = (a - (1 as libc::c_int));
        
        tmp_id_59 = true;
        
      }
      1 => {
        a = (a + (1 as libc::c_int));
        
        tmp_id_60 = (5 as libc::c_int);
        
      }
      _ => () 
      
    };
    
  }
  
  return a;
  
}

#[no_mangle]
unsafe extern "C" fn main() -> libc::c_int
{
  return (0 as libc::c_int);
  
  return (0 as libc::c_int);
  
}


