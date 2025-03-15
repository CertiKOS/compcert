use rust_project::idiomatic_nested_loops::break_multiple;
use rust_project::idiomatic_switch::idiomatic_switch;

#[test]
pub fn test_idiomatic_switch() {
    unsafe {
        assert_eq!(idiomatic_switch(-1), 1);
        assert_eq!(idiomatic_switch(0), 1);
        assert_eq!(idiomatic_switch(1), 3);
        assert_eq!(idiomatic_switch(2), 5);
    }
}

#[test]
pub fn test_break_multiple_loops() {
    unsafe {
        assert_eq!(break_multiple(0), 4);
        assert_eq!(break_multiple(1), 5);
        assert_eq!(break_multiple(3), 9);
        assert_eq!(break_multiple(4), 9);
        assert_eq!(break_multiple(6), 10);
    }
}
