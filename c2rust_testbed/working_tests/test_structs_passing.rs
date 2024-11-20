const BUFFER_SIZE: usize = 9;
use libc::{c_int, c_uint, size_t};
use rust_project::structs::{
    alignment_entry,
    entry_structs, /* TODO where did this naming information go?? Aligned8Struct*/
};
use std::mem::align_of;
const BUFFER_SIZE: usize = 9;

#[test]
pub fn test_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [1, 2, 3, 10, 20, 0, 0, 0, 0];

    unsafe {
        entry_structs(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
