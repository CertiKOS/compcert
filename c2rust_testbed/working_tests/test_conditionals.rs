//use crate::binary_conditional::rust_entry3;
use libc::{c_int, c_uint};
use rust_project::conditional::entry;
use rust_project::conditionals::{entry2_cond, ternaries};
use rust_project::else_if_chain::entry4;
use rust_project::unused_conditionals::{
    unused_conditional1, unused_conditional2, unused_conditional3,
};

const BUFFER_SIZE: usize = 4;
const BUFFER_SIZE2: usize = 30;
const BUFFER_SIZE3: usize = 6;

#[test]
pub fn test_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [0, 0, 2, 3];

    unsafe {
        entry(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}

#[test]
pub fn test_buffer2() {
    let mut buffer = [0; BUFFER_SIZE2];
    let expected_buffer = [
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];

    unsafe {
        entry2_cond(BUFFER_SIZE2 as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}

//pub fn test_binary_conditionals() {
//    let mut buffer = [0; BUFFER_SIZE3];
//    let expected_buffer = [1, 2, 2, 3, 4, 0];
//
//    unsafe {
//        entry3(BUFFER_SIZE3 as u32, buffer.as_mut_ptr());
//    }
//
//    assert_eq!(buffer, expected_buffer);
//}

#[test]
pub fn test_unused_conditional() {
    unsafe {
        assert_eq!(unused_conditional1(), 2);
        assert_eq!(unused_conditional2(), 2);
        assert_eq!(unused_conditional3(), 2);
    }
}

#[test]
pub fn test_else_if_chain() {
    unsafe {
        assert_eq!(0, entry4(0));
        assert_eq!(10, entry4(10));
        assert_eq!(20, entry4(20));
        assert_eq!(-1, entry4(30));
    }
}