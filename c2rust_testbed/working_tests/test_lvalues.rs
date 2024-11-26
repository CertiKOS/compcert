use libc::c_int;
use rust_project::lvalues::lvalue;

const BUFFER_SIZE: usize = 6;

#[test]
pub fn test_lvalue() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [8, 9, 3, 6, 7, -8];

    unsafe {
        lvalue(buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
