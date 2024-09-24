use crate::genann::{GLOBAL_CONST, genann, genann_free, genann_init, genann_run, genann_train, };

static mut __stringlit_3 : [ libc::c_uchar; 34] = b"Output for [%1.f, %1.f] is %1.f.\n\0";

static mut __stringlit_2 : [ libc::c_uchar; 62] = b"Train a small ANN to the XOR function using backpropagation.\n\0";

static mut __stringlit_1 : [ libc::c_uchar; 22] = b"GENANN example 1. %d\n\0";

#[no_mangle]
pub unsafe extern "C" fn main(argc : libc::c_int, argv : *mut *mut libc::c_schar) -> libc::c_int
{
  let mut input : [ [ libc::c_double; 2]; 4];
  let mut output : [ libc::c_double; 4];
  let mut i : libc::c_int;
  let mut ann : *mut genann;
  let mut tmp_id_173 : *mut libc::c_double;
  let mut tmp_id_172 : *mut libc::c_double;
  let mut tmp_id_171 : *mut libc::c_double;
  let mut tmp_id_170 : *mut libc::c_double;
  let mut tmp_id_169 : *mut genann;
  GLOBAL_CONST = (7 as libc::c_int);
  printf(__stringlit_1, GLOBAL_CONST);
  printf(__stringlit_2);
  (*DEREF((*DEREF(input + (0 as libc::c_int))) + (0 as libc::c_int))) =
    (0 as libc::c_int);
  (*DEREF((*DEREF(input + (0 as libc::c_int))) + (1 as libc::c_int))) =
    (0 as libc::c_int);
  (*DEREF((*DEREF(input + (1 as libc::c_int))) + (0 as libc::c_int))) =
    (0 as libc::c_int);
  (*DEREF((*DEREF(input + (1 as libc::c_int))) + (1 as libc::c_int))) =
    (1 as libc::c_int);
  (*DEREF((*DEREF(input + (2 as libc::c_int))) + (0 as libc::c_int))) =
    (1 as libc::c_int);
  (*DEREF((*DEREF(input + (2 as libc::c_int))) + (1 as libc::c_int))) =
    (0 as libc::c_int);
  (*DEREF((*DEREF(input + (3 as libc::c_int))) + (0 as libc::c_int))) =
    (1 as libc::c_int);
  (*DEREF((*DEREF(input + (3 as libc::c_int))) + (1 as libc::c_int))) =
    (1 as libc::c_int);
  (*DEREF(output + (0 as libc::c_int))) = (0 as libc::c_int);
  (*DEREF(output + (1 as libc::c_int))) = (1 as libc::c_int);
  (*DEREF(output + (2 as libc::c_int))) = (1 as libc::c_int);
  (*DEREF(output + (3 as libc::c_int))) = (0 as libc::c_int);
  tmp_id_169 =
    genann_init
    ((2 as libc::c_int), (1 as libc::c_int), (2 as libc::c_int), (1 as libc::c_int));
  ann = tmp_id_169;
  i = (0 as libc::c_int);
  'lbl_0: loop {
    if !((i < (300 as libc::c_int))) {
      break 'lbl_0;
    }
    genann_train
      (ann, (*DEREF(input + (0 as libc::c_int))), (output + (0 as libc::c_int)), (3 as libc::c_int));
    genann_train
      (ann, (*DEREF(input + (1 as libc::c_int))), (output + (1 as libc::c_int)), (3 as libc::c_int));
    genann_train
      (ann, (*DEREF(input + (2 as libc::c_int))), (output + (2 as libc::c_int)), (3 as libc::c_int));
    genann_train
      (ann, (*DEREF(input + (3 as libc::c_int))), (output + (3 as libc::c_int)), (3 as libc::c_int));
    i = (i + (1 as libc::c_int));
  }
  tmp_id_170 = genann_run(ann, (*DEREF(input + (0 as libc::c_int))));
  printf
    (__stringlit_3, (*DEREF((*DEREF(input + (0 as libc::c_int))) + (0 as libc::c_int))), (*DEREF((*DEREF(input + (0 as libc::c_int))) + (1 as libc::c_int))), (*DEREFtmp_id_170));
  tmp_id_171 = genann_run(ann, (*DEREF(input + (1 as libc::c_int))));
  printf
    (__stringlit_3, (*DEREF((*DEREF(input + (1 as libc::c_int))) + (0 as libc::c_int))), (*DEREF((*DEREF(input + (1 as libc::c_int))) + (1 as libc::c_int))), (*DEREFtmp_id_171));
  tmp_id_172 = genann_run(ann, (*DEREF(input + (2 as libc::c_int))));
  printf
    (__stringlit_3, (*DEREF((*DEREF(input + (2 as libc::c_int))) + (0 as libc::c_int))), (*DEREF((*DEREF(input + (2 as libc::c_int))) + (1 as libc::c_int))), (*DEREFtmp_id_172));
  tmp_id_173 = genann_run(ann, (*DEREF(input + (3 as libc::c_int))));
  printf
    (__stringlit_3, (*DEREF((*DEREF(input + (3 as libc::c_int))) + (0 as libc::c_int))), (*DEREF((*DEREF(input + (3 as libc::c_int))) + (1 as libc::c_int))), (*DEREFtmp_id_173));
  genann_free(ann);
  return (0 as libc::c_int);
  return (0 as libc::c_int);
}


