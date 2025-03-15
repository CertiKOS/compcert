use rust_project::goto_linear_cf::goto_linear;
use rust_project::goto_loop_cf::goto_loop;
use rust_project::goto_switch_cf::goto_switch;

use libc::{c_int, c_uint};

const BUFFER_SIZE: usize = 4;
const BUFFER_SIZE2: usize = 12;
const BUFFER_SIZE3: usize = 6;

#[test]
pub fn test_goto_linear() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [0, 1, 3, 2];

    unsafe {
        goto_linear(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }
    assert_eq!(buffer, expected_buffer);
}

#[test]
pub fn test_goto_loop() {
    let mut buffer = [0; BUFFER_SIZE2];
    let expected_buffer = [0, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1];

    unsafe {
        goto_loop(BUFFER_SIZE2 as u32, buffer.as_mut_ptr());
    }
    assert_eq!(buffer, expected_buffer);
}

#[test]
pub fn test_goto_switch() {
    let mut buffer = [0; BUFFER_SIZE3];
    let expected_buffer = [0, 1, 1, 1, 2, 3];

    unsafe {
        goto_switch(BUFFER_SIZE3 as u32, buffer.as_mut_ptr());
    }
    assert_eq!(buffer, expected_buffer);
}
