use libc::{c_int, c_uint};
use rust_project::chars::multibyte_chars;

const BUFFER_SIZE: usize = 10;

#[test]
pub fn test_chars_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = ['✓' as i32, '😱' as i32, '😱' as i32, 0, 1, -1, 0, 0, 0, 0];

    unsafe {
        assert!(multibyte_chars(BUFFER_SIZE as u32, buffer.as_mut_ptr()) as usize <= BUFFER_SIZE);
    }

    assert_eq!(buffer, expected_buffer);
}
