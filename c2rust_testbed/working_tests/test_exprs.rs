use libc::c_int;
use libc::c_uint;
use rust_project::exprs::exprs;

const BUFFER_SIZE: usize = 60;

#[test]
pub fn test_exprs() {
    let mut buffer = [0; BUFFER_SIZE];
    let mut expected_buffer = [
        1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];

    unsafe {
        exprs(BUFFER_SIZE as c_uint, buffer.as_mut_ptr());
    }

    for x in 0..BUFFER_SIZE {
        assert_eq!(buffer[x], expected_buffer[x], "index {}", x);
    }
}
