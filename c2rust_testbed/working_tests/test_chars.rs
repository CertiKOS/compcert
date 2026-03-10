use libc::{c_int, c_uint};
use rust_project::chars::multibyte_chars;
use std::fs;

const BUFFER_SIZE: usize = 10;

fn compcert_char_is_signed() -> bool {
    let config = fs::read_to_string(concat!(env!("CARGO_MANIFEST_DIR"), "/../../../Makefile.config"))
        .expect("Makefile.config should exist after CompCert bootstrap");
    let mut arch = None;
    let mut system = None;

    for line in config.lines() {
        if let Some(value) = line.strip_prefix("ARCH=") {
            arch = Some(value);
        } else if let Some(value) = line.strip_prefix("SYSTEM=") {
            system = Some(value);
        }
    }

    matches!((arch, system), (Some("x86"), _) | (Some("aarch64"), Some("macos")))
}

#[test]
pub fn test_chars_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let char_ff = if compcert_char_is_signed() { -1 } else { 255 };
    let expected_buffer = ['✓' as i32, '😱' as i32, '😱' as i32, 0, 1, char_ff, 0, 0, 0, 0];

    unsafe {
        assert!(multibyte_chars(BUFFER_SIZE as u32, buffer.as_mut_ptr()) as usize <= BUFFER_SIZE);
    }

    assert_eq!(buffer, expected_buffer);
}
