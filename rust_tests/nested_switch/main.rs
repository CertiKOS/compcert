#[no_mangle]
unsafe extern "C" fn nested_switch_example(
    outer_var: libc::c_int,
    inner_var: libc::c_int,
) -> libc::c_int {
    let mut result: libc::c_int;
    let mut tmp_id_63: libc::c_int;
    let mut tmp_id_62: bool;
    let mut tmp_id_61: libc::c_int;
    let mut tmp_id_60: bool;
    result = 0;

    tmp_id_60 = true;

    tmp_id_61 = outer_var;

    'lbl_0: loop {
        if tmp_id_60 {
            result = -1;

            break 'lbl_0;

            tmp_id_61 = 1;

            tmp_id_60 = false;
        }
        match tmp_id_61 {
            2 => {
                result = 3;

                break 'lbl_0;

                break 'lbl_0;
            }
            1 => {
                tmp_id_62 = true;

                tmp_id_63 = inner_var;

                'lbl_1: loop {
                    if tmp_id_62 {
                        result = -2;

                        tmp_id_63 = 1;

                        tmp_id_62 = false;
                    }
                    match tmp_id_63 {
                        2 => {
                            result = 2;

                            break 'lbl_1;

                            break 'lbl_1;
                        }
                        1 => {
                            result = 1;

                            break 'lbl_1;

                            tmp_id_63 = 2;
                        }
                        _ => (),
                    };
                }
                break 'lbl_0;

                tmp_id_61 = 2;
            }
            _ => (),
        };
    }
    return result;
}

#[no_mangle]
unsafe extern "C" fn main() -> libc::c_int {
    return 5;

    return 0;
}
