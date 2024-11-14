#[test]
pub fn test_buffer() {
    let mut buffer = [0; BUFFER_SIZE];

    unsafe {
        entry(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, rust_buffer);
}
