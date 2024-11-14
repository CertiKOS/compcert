use libc::{c_int, c_uint};
use rust_project::const_test::entry5;

const BUFFER_SIZE: usize = 2;

#[test]
pub fn test_const() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [3, 2];

    unsafe {
        entry5(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
