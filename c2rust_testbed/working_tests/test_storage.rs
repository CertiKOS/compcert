use libc::{c_int, c_uint};
use rust_project::storage::entry_storage;

const BUFFER_SIZE: usize = 11;

#[test]
pub fn test_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [1, 4, 2, 0, 0, 0, 0, 4, 4, 104, 111];

    unsafe {
        entry_storage(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
