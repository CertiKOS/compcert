use libc::{c_int, c_uint, c_ulong};
use rust_project::define::fns;
use rust_project::define::test_zstd;
//, stmt_expr_inc};
use rust_project::define::reference_define;
// TODO macros are not preserved
//, TEST_CONST1, TEST_CONST2, TEST_PARENS};
// TODO macros are not preserved
//, ZSTD_WINDOWLOG_MAX_32, ZSTD_WINDOWLOG_MAX_64};

#[test]
pub fn test_define() {
    let rust_x = unsafe { reference_define() };
    assert_eq!(rust_x, 1 + 2 + 3 * 3 as c_int);
}

#[test]
pub fn test_zstd_define() {
    let max = unsafe { test_zstd() } as i32;

    assert!(max == 30 || max == 31);
}

// NOTE uses statement expressions which is gnu extension and not supported
//pub fn test_macro_stmt_expr() {
//    let ret = unsafe { stmt_expr_inc() };
//
//    assert_eq!(ret, 2);
//}
