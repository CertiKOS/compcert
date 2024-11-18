use rust_project::nofnargs::nofnargs;
use rust_project::noop::noop;

use libc::c_int;

#[test]
pub fn test_noop() {
    unsafe {
        noop();
    }
}

#[test]
pub fn test_nofnargs() {
    let ret = unsafe { nofnargs() };

    assert_eq!(ret, 0);
}
