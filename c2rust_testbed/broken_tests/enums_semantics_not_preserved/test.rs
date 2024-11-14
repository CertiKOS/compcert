use rust_project::enum_as_int::{A, B, E};
use rust_project::top_enum::{E as otherE};
use rust_project::enum_ret::{Color};
use rust_project::enum_duplicate::{e};

#[test]
pub fn test_variants() {
    assert_eq!(A as u32, 0);
    assert_eq!(B as u32, 1);
}
