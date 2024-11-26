//! xfail

use libc::{c_int, c_uint};
use rust_project::implicit_int::{identity2, implicit_int};

#[test]
pub fn test_identity() {
    unsafe {
        assert_eq!(identity2(1), 1);
    }
}

#[test]
pub fn test_implicit_int() {
    unsafe {
        implicit_int();
    }
}
