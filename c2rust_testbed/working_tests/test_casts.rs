use rust_project::cast_funptr::{get_identity, identity};

use libc::{c_int, c_uint, c_void};

use std::mem::transmute;

const BUFFER_SIZE: usize = 1;

#[test]
pub fn test_identity() {
    for i in 0..10 {
        let id = unsafe { identity(i) };

        assert_eq!(id, i);
    }

    let transmuted_identity: unsafe extern "C" fn(_: libc::c_int) -> libc::c_int =
        unsafe { transmute(get_identity()) };

    for i in 0..10 {
        let id = unsafe { transmuted_identity(i) };

        assert_eq!(id, i);
    }
}
