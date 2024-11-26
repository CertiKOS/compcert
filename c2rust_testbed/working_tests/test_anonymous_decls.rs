use libc::{c_int, c_uint};
use rust_project::anonymous_decls::k;

#[test]
pub fn test_anonymous_decl() {
    unsafe {
        assert_eq!(k.j.l, 0);
    }
}
