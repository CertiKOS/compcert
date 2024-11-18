use crate::incomplete_arrays::{rust_check_some_ints, rust_entry2, rust_test_sized_array};
use libc::{c_int, c_uint};

#[no_mangle]
pub static SOME_INTS: [u32; 4] = [2, 0, 1, 8];

const BUFFER_SIZE2: usize = 2;

#[test]
pub fn test_sized_array_impls() {
    unsafe {
        assert_eq!(rust_test_sized_array(), test_sized_array());
    }
}

#[test]
pub fn test_global_incomplete_array() {
    unsafe {
        assert_eq!(rust_check_some_ints(), check_some_ints());
    }
}

#[test]
pub fn test_buffer2() {
    let mut buffer = [0; BUFFER_SIZE2];
    let mut rust_buffer = [0; BUFFER_SIZE2];
    let expected_buffer = [1, 1];

    unsafe {
        entry2(BUFFER_SIZE2 as u32, buffer.as_mut_ptr());
        rust_entry2(BUFFER_SIZE2 as u32, rust_buffer.as_mut_ptr());
    }

    assert_eq!(buffer, rust_buffer);
    assert_eq!(buffer, expected_buffer);
}
