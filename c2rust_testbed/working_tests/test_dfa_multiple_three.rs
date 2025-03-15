use rust_project::dfa_binary_multiple_three::multiple_three;

use std::ffi::CString;

#[test]
pub fn test_multiple_three() {
    let n1 = CString::new(format!("{:b}", 4529465 * 3 + 0)).unwrap();
    let n2 = CString::new(format!("{:b}", 65424738 * 3 + 1)).unwrap();
    let n3 = CString::new(format!("{:b}", 98078783 * 3 + 2)).unwrap();
    let n4 = CString::new("010100150101010001").unwrap();

    unsafe {
        assert_eq!(multiple_three(n1.as_ptr() as *mut _), 1);
        assert_eq!(multiple_three(n2.as_ptr() as *mut _), 0);
        assert_eq!(multiple_three(n3.as_ptr() as *mut _), 0);
        assert_eq!(multiple_three(n4.as_ptr() as *mut _), 2);
    }
}
