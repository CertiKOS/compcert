use rust_project::comments::test_fn;
// TODO note that this holds onto the macro expansion of constant whereas it's lost for us

#[test]
pub fn test_comments() {
    let val = unsafe { test_fn() };
    assert_eq!(6, val);
}
