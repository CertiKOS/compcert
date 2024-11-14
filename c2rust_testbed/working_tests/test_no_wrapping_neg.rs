use libc::{c_double, c_float};
use rust_project::no_float_wrapping_neg::{double_inc_dec, float_inc_dec, no_wrapping_neg};

#[test]
pub fn test_buffer() {
    unsafe {
        assert_eq!(no_wrapping_neg(), -1.);
    }
}

#[test]
pub fn test_inc_dec_op() {
    unsafe {
        assert_eq!(float_inc_dec(), -0.79999995);
        assert_eq!(double_inc_dec(), -0.7999999999999998);
    }
}
