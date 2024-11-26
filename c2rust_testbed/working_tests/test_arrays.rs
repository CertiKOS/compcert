use libc::{c_int, c_uint};
use rust_project::arrays::entry_arrays;

#[no_mangle]
pub static SOME_INTS: [u32; 4] = [2, 0, 1, 8];

const BUFFER_SIZE: usize = 49;

#[test]
pub fn test_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [
        97, 98, 99, 0, 100, 101, 102, 1, 0, 97, 98, 99, 0, 97, 98, 99, 100, 97, 98, 99, 97, 98, 99,
        0, 0, 0, 0, 120, 0, 120, 0, 0, 120, 109, 121, 115, 116, 114, 105, 110, 103, 109, 121, 115,
        116, 114, 105, 110, 103,
    ];

    unsafe {
        entry_arrays(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    for index in 0..BUFFER_SIZE {
        assert_eq!(buffer[index], expected_buffer[index], "index: {}", index);
    }
}
