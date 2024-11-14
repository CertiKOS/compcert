//use crate::big_enum::{rust_entry5, E1, E2, E3};
//use crate::enum_fwd_decl::rust_foo;
//use crate::non_canonical_enum_def::{
//    hrtimer_restart, rust_abc, HRTIMER_NORESTART, HRTIMER_RESTART,
//};
//

//pub fn test_buffer5() {
//    let mut buffer = [0; BUFFER_SIZE5];
//    let mut rust_buffer = [0; BUFFER_SIZE5];
//    let expected_buffer = [1, 0, 1, 0, 1, 0];
//
//    unsafe {
//        entry5(BUFFER_SIZE5 as u32, buffer.as_mut_ptr());
//        rust_entry5(BUFFER_SIZE5 as u32, rust_buffer.as_mut_ptr());
//    }
//
//    assert_eq!(buffer, rust_buffer);
//    assert_eq!(buffer, expected_buffer);
//}
