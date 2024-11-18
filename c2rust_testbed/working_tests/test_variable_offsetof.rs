//! extern_crate_memoffset

use rust_project::variable_offsetof::{get_offset, get_offset2};

#[test]
pub fn test_get_offset() {
    let expected = [(4, 4), (8, 8), (12, 12)];
    for idx in 0..3usize {
        let rust_ret = unsafe { get_offset(idx as _) };

        assert_eq!(rust_ret, expected[idx].0);

        let rust_ret2 = unsafe { get_offset2(idx as _) };

        assert_eq!(rust_ret2, expected[idx].1);
    }
}
