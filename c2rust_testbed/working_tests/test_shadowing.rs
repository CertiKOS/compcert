use libc::{c_int, c_uint};
use rust_project::shadowing::{shadow, twice};

const BUFFER_SIZE: usize = 10;

#[test]
pub fn test_twice() {
    for i in 0..20 {
        let double = unsafe { twice(i) };

        assert_eq!(double, (i * 2));
    }
}

#[test]
pub fn test_shadowing() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [10, 6, 12, 18, 24, 30, 36, 42, 48, 54];

    unsafe {
        shadow(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}
