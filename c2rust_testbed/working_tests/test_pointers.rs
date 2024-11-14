use libc::{c_int, c_uint};
use rust_project::pointer_arith::entry13;
use rust_project::pointer_init::entry14;

const BUFFER_SIZE: usize = 5;
const BUFFER_SIZE2: usize = 31;
const BUFFER_SIZE3: usize = 18;

#[test]
pub fn test_init() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [115, 116, 114, 105, 110];

    unsafe {
        entry14(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}

#[test]
pub fn test_arith() {
    let mut buffer = [0; BUFFER_SIZE2];
    let expected_buffer = [
        1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 33, 1, 1, 1, 1, 1, 1, 35, 1, 1,
        34,
    ];

    unsafe {
        entry13(BUFFER_SIZE2 as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
