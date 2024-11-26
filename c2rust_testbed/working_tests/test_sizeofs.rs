//! feature_core_intrinsics, feature_label_break_value

use libc::c_int;
use libc::c_uint;
use rust_project::sizeofs::sizeofs;

const BUFFER_SIZE: usize = 60;

#[test]
pub fn test_sizeofs() {
    let mut expected_buffer = [
        1, 1, 1, 1, 4, 4, 8, 8, 4, 4, 8, 8, 4, 4, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 4,
        4, 4, 16, 4, 80, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];

    let mut buffer = [0; BUFFER_SIZE];

    unsafe {
        sizeofs(BUFFER_SIZE as c_uint, buffer.as_mut_ptr());
    }

    for x in 0..BUFFER_SIZE {
        assert_eq!(buffer[x], expected_buffer[x], "index {}", x);
    }
}
