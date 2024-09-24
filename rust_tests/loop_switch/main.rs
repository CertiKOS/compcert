#[no_mangle]
unsafe extern "C" fn switch_in_loop(size : libc::c_int, a : libc::c_int, b : libc::c_int, ) -> libc::c_int
{
  let mut sum : libc::c_int;
  let mut tmp_id_62 : libc::c_int;
  let mut tmp_id_61 : bool;
  sum = 0;

  'lbl_0: loop {
    /* skip stmt */
    tmp_id_61 = false;

    tmp_id_62 = size;

    'lbl_1: loop {
      if tmp_id_61 {
        sum = (sum + 5);

        break 'lbl_1;

        break 'lbl_1;

      }
      match tmp_id_62 {
        2 => {
          sum = (sum + 20);

          break 'lbl_1;

          tmp_id_61 = true;

        }
        1 => {
          sum = (sum + 10);

          break 'lbl_1;

          tmp_id_62 = 2;

        }
        0 => {
          continue 'lbl_0;
          tmp_id_62 = 1;

        }
        _ => ()

      };
    }
  }
  return sum;

}

#[no_mangle]
unsafe extern "C" fn main() -> libc::c_int
{
  let mut a : libc::c_int;
  let mut tmp_id_61 : libc::c_int;
  tmp_id_61 = switch_in_loop(5, 6, 7);
  a = tmp_id_61;

  return 0;

}


