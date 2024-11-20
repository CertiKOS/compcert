// TODO justin: lost the enums, should preserve that information
use rust_project::big_enum::{entry5_big_enum /*, E1, E2, E3*/};

const BUFFER_SIZE5: usize = 6;

#[test]
pub fn test_buffer5() {
    let mut buffer = [0; BUFFER_SIZE5];
    let expected_buffer = [1, 0, 1, 0, 1, 0];

    unsafe {
        entry5_big_enum(BUFFER_SIZE5 as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
