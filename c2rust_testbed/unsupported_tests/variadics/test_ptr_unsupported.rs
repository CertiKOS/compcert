//use rust_project::function_pointers::rust_entry3;
//
//pub fn test_fn_ptrs() {
//    let mut buffer = [0; BUFFER_SIZE3];
//    let mut rust_buffer = [0; BUFFER_SIZE3];
//    let expected_buffer = [
//        97, 97, 97, -98, 1, 0, 0, 1, 65, 66, 68, 69, 97, 97, 97, 1, 97, 98,
//    ];
//
//    unsafe {
//        entry3(BUFFER_SIZE3 as u32, buffer.as_mut_ptr());
//        rust_entry3(BUFFER_SIZE3 as u32, rust_buffer.as_mut_ptr());
//    }
//
//    assert_eq!(&buffer[..], &expected_buffer[..], "c version");
//    assert_eq!(&rust_buffer[..], &expected_buffer[..], "rust version");
//}
