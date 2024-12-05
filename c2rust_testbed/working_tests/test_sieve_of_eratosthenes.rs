use libc::c_int;
use rust_project::sieve_of_eratosthenes::sieve_of_eratosthenes;

const BUFFER_SIZE: usize = 102;

#[test]
pub fn test_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [
        0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1,
        0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1,
        0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1,
    ];

    unsafe {
        sieve_of_eratosthenes(buffer.as_mut_ptr());
    }

    for index in 0..BUFFER_SIZE {
        assert_eq!(buffer[index], expected_buffer[index], "idx: {}", index);
    }
}
