use rust_project::enum_as_int::entry8;
use rust_project::enum_duplicate::entry9;
use rust_project::enum_ret::entry10;
use rust_project::top_enum::entry11;

use libc::{c_int, c_uint};

const BUFFER_SIZE: usize = 10;
const BUFFER_SIZE2: usize = 7;
const BUFFER_SIZE3: usize = 4;
const BUFFER_SIZE4: usize = 1;
const BUFFER_SIZE5: usize = 6;

#[test]
pub fn test_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [1, 1, 1, 1, 1, 1, 0, 0, 0, 0];

    unsafe {
        entry8(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}

#[test]
pub fn test_buffer2() {
    let mut buffer = [0; BUFFER_SIZE2];
    let expected_buffer = [1, 2, -1, 1, -2, 1, 6];

    unsafe {
        entry10(BUFFER_SIZE2 as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}

#[test]
pub fn test_buffer3() {
    let mut buffer = [0; BUFFER_SIZE3];
    let expected_buffer = [0, 0, -10, -9];

    unsafe {
        entry9(BUFFER_SIZE3 as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}

#[test]
pub fn test_buffer4() {
    let mut buffer = [0; BUFFER_SIZE4];
    let expected_buffer = [1];

    unsafe {
        entry11(BUFFER_SIZE4 as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
