use rust_project::early_returns::early_returns;

#[test]
pub fn test_early_returns() {
    unsafe {
        assert_eq!(early_returns(2), 2);
        assert_eq!(early_returns(3), 1);
        assert_eq!(early_returns(4), 1);
        assert_eq!(early_returns(5), 0);
    }
}
