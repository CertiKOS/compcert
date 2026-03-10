use libc::c_int;
use rust_project::irreducible::irreducible;

#[test]
pub fn test_irreducible() {
    let expected_values = [
        91, 92, 93, 94, 95, 96, 100, 99, 100, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
    ];
    unsafe {
        for i in 0..20 {
            assert_eq!(expected_values[i], irreducible(i as i32));
        }
    }
}
