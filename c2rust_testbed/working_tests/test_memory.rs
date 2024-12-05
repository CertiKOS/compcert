use libc::{c_int, c_uint};
use rust_project::malloc::malloc_test;
use rust_project::strings_h::setmem;

const BUFFER_SIZE: usize = 3;
const BUFFER_SIZE2: usize = 5;

#[test]
pub fn test_malloc() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [34, 35, 36];

    unsafe {
        malloc_test(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}

#[test]
pub fn test_memset() {
    let mut buffer = [0; BUFFER_SIZE2];
    let expected_buffer = [16843009; BUFFER_SIZE2];

    unsafe {
        setmem(BUFFER_SIZE2 as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
