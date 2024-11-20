use libc::{c_int, c_uint};
use rust_project::size_t::entry_sizet;

const BUFFER_SIZE: usize = 10;

#[test]
pub fn test_size_t_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [0, 0, 0, 0, 0, 8, 0, 0, 0, 0];

    unsafe {
        entry_sizet(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
