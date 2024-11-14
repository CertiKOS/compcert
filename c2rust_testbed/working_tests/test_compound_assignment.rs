use rust_project::compound_assignment::compound_assignment;

use libc::{c_int, c_uint};

const BUFFER_SIZE: usize = 13;

#[test]
pub fn test_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [129, 0, 55, 0, 0, 0, 0, 55, 0, 0, 2100, 129, 183];

    unsafe {
        compound_assignment(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
