use libc::c_int;
use rust_project::qsort::{partition, quickSort, swap};

#[test]
pub fn test_swap() {
    let (mut a, mut b) = (1, 2);

    unsafe {
        swap(&mut a, &mut b);
    }

    assert_eq!(a, 2);
    assert_eq!(b, 1);

    unsafe { swap(&mut a, &mut b) }

    assert_eq!(a, 1);
    assert_eq!(b, 2);
}

#[test]
pub fn test_partition() {
    let mut buffer = [6, 1, 5, 6, 2, 0, 9, 2, 0, 5];
    let expected_buffer = [1, 5, 2, 0, 2, 0, 5, 6, 6, 9];

    unsafe {
        partition(buffer.as_mut_ptr(), 0, 9);
    }

    assert_eq!(buffer, expected_buffer);
}

#[test]
pub fn test_quicksort() {
    let mut buffer = [6, 1, 5, 6, 2, 0, 9, 2, 0, 5];
    let expected_buffer = [0, 0, 1, 2, 2, 5, 5, 6, 6, 9];

    unsafe {
        quickSort(buffer.as_mut_ptr(), 0, 9);
    };

    assert_eq!(buffer, expected_buffer);
}
