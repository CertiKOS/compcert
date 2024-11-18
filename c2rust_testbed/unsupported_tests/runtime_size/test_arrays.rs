use crate::variable_arrays::{rust_alloca_arrays, rust_variable_arrays};
use libc::{c_int, c_uint};


#[no_mangle]
pub static SOME_INTS: [u32; 4] = [2, 0, 1, 8];
#[no_mangle]
pub static rust_SOME_INTS: [u32; 4] = [2, 0, 1, 8];

const BUFFER_SIZE: usize = 49;
const BUFFER_SIZE2: usize = 2;
const BUFFER_SIZEV: usize = 88;

pub fn test_variable_arrays() {
    let mut buffer = [0; BUFFER_SIZEV];
    let mut rust_buffer = [0; BUFFER_SIZEV];
    let expected_buffer = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
        26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33,
        34, 35, 36, 37, 38, 39, 40, 0, 3, 6, 9, 12, 15, 18, 21,
    ];
    unsafe {
        variable_arrays(buffer.as_mut_ptr());
        rust_variable_arrays(rust_buffer.as_mut_ptr());
    }

    for index in 0..BUFFER_SIZEV {
        assert_eq!(buffer[index], expected_buffer[index], "index: {}", index);
        assert_eq!(buffer[index], rust_buffer[index], "index: {}", index);
    }
}

pub fn test_alloca_arrays() {
    let mut buffer = [0; BUFFER_SIZEV];
    let mut rust_buffer = [0; BUFFER_SIZEV];
    let expected_buffer = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
        26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33,
        34, 35, 36, 37, 38, 39, 40, 0, 3, 6, 9, 12, 15, 18, 21,
    ];
    unsafe {
        alloca_arrays(buffer.as_mut_ptr());
        rust_alloca_arrays(rust_buffer.as_mut_ptr());
    }

    for index in 0..BUFFER_SIZEV {
        assert_eq!(buffer[index], expected_buffer[index], "index: {}", index);
        assert_eq!(buffer[index], rust_buffer[index], "index: {}", index);
    }
}
