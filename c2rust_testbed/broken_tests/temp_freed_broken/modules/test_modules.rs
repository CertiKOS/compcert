use crate::modules::rust_modules;
use libc::c_uint;

#[link(name = "test")]
extern "C" {
    fn modules();
}

#[test]
pub fn test_modules() {}
