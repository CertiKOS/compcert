use libc::{c_int, c_uint};
use rust_project::uninitialized::{
    /*bar,*/ /*baz,*/ /* e,*/ entry2, /*foo,*/ s, /*myint, myintp,*/ u,
};

const BUFFER_SIZE: usize = 1;

#[test]
pub fn test_buffer() {
    let mut buffer = [0; BUFFER_SIZE];
    let expected_buffer = [1];

    unsafe {
        entry2(BUFFER_SIZE as u32, buffer.as_mut_ptr());
    }

    assert_eq!(buffer, expected_buffer);
}

// TODO broken enum test because semantic enum information is lost.
// unclear if we care
#[test]
pub fn test_types() {
    //    assert_eq!(foo as u32, 1);
    //    assert_eq!(bar as u32, 2);
    //    assert_eq!(baz as u32, 3);
    //
    //    // FIXME: union fields are private
    let my_union = u { x: 32 };

    let my_struct = s {
        a_u: my_union,
        a_c: 1,
        a_e: 1,
        // TODO lost enum information
        //a_e: e::foo,
    };
}
