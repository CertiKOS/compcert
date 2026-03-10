use libc::c_int;
use rust_project::switch::switch_val;

#[test]
pub fn test_switch() {
    let val = unsafe { switch_val(1) };

    assert_eq!(val, 2);

    let val = unsafe { switch_val(2) };

    assert_eq!(val, 4);

    let val = unsafe { switch_val(10) };

    assert_eq!(val, 11);
}
