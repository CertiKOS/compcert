
#[repr(C)]
pub struct __sbuf {
   _base : *mut libc::c_uchar,
   _size : libc::c_int,
}
 
#[repr(C)]
pub struct __sFILE {
   _p : *mut libc::c_uchar,
   _r : libc::c_int,
   _w : libc::c_int,
   _flags : libc::c_short,
   _file : libc::c_short,
   _bf : __sbuf,
   _lbfsize : libc::c_int,
   _cookie : *mut libc::c_void,
   _close : *mut (fn(*mut libc::c_void) -> libc::c_int),
   _read : *mut (fn(*mut libc::c_void,*mut libc::c_schar,libc::c_int) -> libc::c_int),
   _seek : *mut (fn(*mut libc::c_void,libc::c_longlong,libc::c_int) -> libc::c_longlong),
   _write : *mut (fn(*mut libc::c_void,*mut libc::c_schar,libc::c_int) -> libc::c_int),
   _ub : __sbuf,
   _extra : *mut __sFILEX,
   _ur : libc::c_int,
   _ubuf : [ libc::c_uchar; 3],
   _nbuf : [ libc::c_uchar; 1],
   _lb : __sbuf,
   _blksize : libc::c_int,
   _offset : libc::c_longlong,
}
 
#[repr(C)]
pub struct genann {
   inputs : libc::c_int,
   hidden_layers : libc::c_int,
   hidden : libc::c_int,
   outputs : libc::c_int,
   activation_hidden : *mut (fn(libc::c_double) -> libc::c_double),
   activation_output : *mut (fn(libc::c_double) -> libc::c_double),
   total_weights : libc::c_int,
   total_neurons : libc::c_int,
   weight : *mut libc::c_double,
   output : *mut libc::c_double,
   delta : *mut libc::c_double,
}
 
static mut __stringlit_3 : [ libc::c_uchar; 5] = b" %le\0";

static mut __stringlit_7 : [ libc::c_uchar; 38] = b"o - ann->output == ann->total_neurons\0";

static mut __stringlit_5 : [ libc::c_uchar; 9] = b"genann.c\0";

static mut __stringlit_9 : [ libc::c_uchar; 7] = b" %.20e\0";

static mut __stringlit_1 : [ libc::c_uchar; 12] = b"%d %d %d %d\0";

static mut __stringlit_6 : [ libc::c_uchar; 30] = b"%s:%d: failed assertion `%s'\n\0";

static mut __stringlit_2 : [ libc::c_uchar; 7] = b"fscanf\0";

static mut __stringlit_8 : [ libc::c_uchar; 10] = b"%p PTR %d\0";

static mut __stringlit_4 : [ libc::c_uchar; 38] = b"w - ann->weight == ann->total_weights\0";

pub static mut GLOBAL_CONST : libc::c_int = 5;

#[no_mangle]
pub unsafe extern "C" fn genann_act_sigmoid(a : libc::c_double) -> libc::c_double
{
  let mut tmp_id_169 : libc::c_double;
  if (a < -(45 as libc::c_double)) {
    return (0 as libc::c_int);
  }
  if (a > (45 as libc::c_double)) {
    return (1 as libc::c_int);
  }
  tmp_id_169 = exp(-a);
  return ((1 as libc::c_double) / ((1 as libc::c_int) + tmp_id_169));
}

static mut interval : libc::c_double; 

static mut initialized : libc::c_int = 0;

static mut lookup : [ libc::c_double; 4096]; 

#[no_mangle]
pub unsafe extern "C" fn genann_act_sigmoid_cached(a : libc::c_double) -> libc::c_double
{
  let mut min : libc::c_double;
  let mut max : libc::c_double;
  let mut i : libc::c_int;
  let mut i__1 : libc::c_int;
  let mut tmp_id_169 : libc::c_double;
  min = -(15 as libc::c_double);
  max = (15 as libc::c_double);
  if !initialized {
    interval = ((max - min) / (4096 as libc::c_int));
    i = (0 as libc::c_int);
    'lbl_0: loop {
      if !((i < (4096 as libc::c_int))) {
        break 'lbl_0;
      }
      tmp_id_169 = genann_act_sigmoid((min + (interval * i)));
      (*DEREF(lookup + i)) = tmp_id_169;
      i = (i + (1 as libc::c_int));
    }
    initialized = (1 as libc::c_int);
  }
  i__1 = ((((a - min) / interval) + (0.5 as libc::c_double)) as libc::c_int);
  if (i__1 <= (0 as libc::c_int)) {
    return (*DEREF(lookup + (0 as libc::c_int)));
  }
  if (i__1 >= (4096 as libc::c_int)) {
    return (*DEREF(lookup + ((4096 as libc::c_int) - (1 as libc::c_int))));
  }
  return (*DEREF(lookup + i__1));
}

#[no_mangle]
pub unsafe extern "C" fn genann_act_threshold(a : libc::c_double) -> libc::c_double
{
  return (a > (0 as libc::c_int));
}

#[no_mangle]
pub unsafe extern "C" fn genann_act_linear(a : libc::c_double) -> libc::c_double
{
  return a;
}

#[no_mangle]
pub unsafe extern "C" fn genann_init(inputs : libc::c_int, hidden_layers : libc::c_int, hidden : libc::c_int, outputs : libc::c_int) -> *mut genann
{
  let mut hidden_weights : libc::c_int;
  let mut output_weights : libc::c_int;
  let mut total_weights : libc::c_int;
  let mut total_neurons : libc::c_int;
  let mut size : libc::c_int;
  let mut ret : *mut genann;
  let mut tmp_id_172 : *mut libc::c_void;
  let mut tmp_id_171 : libc::c_int;
  let mut tmp_id_170 : libc::c_int;
  let mut tmp_id_169 : libc::c_int;
  if (hidden_layers < (0 as libc::c_int)) {
    return (0 as libc::c_int);
  }
  if (inputs < (1 as libc::c_int)) {
    return (0 as libc::c_int);
  }
  if (outputs < (1 as libc::c_int)) {
    return (0 as libc::c_int);
  }
  if (hidden_layers > (0 as libc::c_int)) {
    tmp_id_169 = ((hidden < (1 as libc::c_int)) as bool);
  } else {
    tmp_id_169 = (0 as libc::c_int);
  }
  if tmp_id_169 {
    return (0 as libc::c_int);
  }
  if hidden_layers {
    tmp_id_170 =
      ((((inputs + (1 as libc::c_int)) * hidden) + (((hidden_layers - (1 as libc::c_int)) * (hidden + (1 as libc::c_int))) * hidden)) as libc::c_int);
  } else {
    tmp_id_170 = ((0 as libc::c_int) as libc::c_int);
  }
  hidden_weights = tmp_id_170;
  if hidden_layers {
    tmp_id_171 = ((hidden + (1 as libc::c_int)) as libc::c_int);
  } else {
    tmp_id_171 = ((inputs + (1 as libc::c_int)) as libc::c_int);
  }
  output_weights = (tmp_id_171 * outputs);
  total_weights = (hidden_weights + output_weights);
  total_neurons = ((inputs + (hidden * hidden_layers)) + outputs);
  size =
    ((std::mem::sizeof::<genann>() as libc::c_ulonglong) + ((std::mem::sizeof::<libc::c_double>() as libc::c_ulonglong) * ((total_weights + total_neurons) + (total_neurons - inputs))));
  tmp_id_172 = malloc(size);
  ret = tmp_id_172;
  if !ret {
    return (0 as libc::c_int);
  }
  (*DEREFret).inputs = inputs;
  (*DEREFret).hidden_layers = hidden_layers;
  (*DEREFret).hidden = hidden;
  (*DEREFret).outputs = outputs;
  (*DEREFret).total_weights = total_weights;
  (*DEREFret).total_neurons = total_neurons;
  (*DEREFret).weight =
    (((ret as *mut libc::c_schar) + (std::mem::sizeof::<genann>() as libc::c_ulonglong)) as *mut libc::c_double);
  (*DEREFret).output = ((*DEREFret).weight + (*DEREFret).total_weights);
  (*DEREFret).delta = ((*DEREFret).output + (*DEREFret).total_neurons);
  genann_randomize(ret);
  (*DEREFret).activation_hidden = genann_act_sigmoid_cached;
  (*DEREFret).activation_output = genann_act_sigmoid_cached;
  return ret;
}

#[no_mangle]
pub unsafe extern "C" fn genann_read(in : *mut __sFILE) -> *mut genann
{
  let mut inputs : libc::c_int;
  let mut hidden_layers : libc::c_int;
  let mut hidden : libc::c_int;
  let mut outputs : libc::c_int;
  let mut rc : libc::c_int;
  let mut ann : *mut genann;
  let mut i : libc::c_int;
  let mut tmp_id_177 : *mut libc::c_int;
  let mut tmp_id_176 : libc::c_int;
  let mut tmp_id_175 : libc::c_int;
  let mut tmp_id_174 : *mut libc::c_int;
  let mut tmp_id_173 : *mut genann;
  let mut tmp_id_172 : *mut libc::c_int;
  let mut tmp_id_171 : libc::c_int;
  let mut tmp_id_170 : libc::c_int;
  let mut tmp_id_169 : *mut libc::c_int;
  tmp_id_169 = __error();
  (*DEREFtmp_id_169) = (0 as libc::c_int);
  tmp_id_170 =
    fscanf
    (in, __stringlit_1, (std::ptr::addr_of_mut!(inputs)), (std::ptr::addr_of_mut!(hidden_layers)), (std::ptr::addr_of_mut!(hidden)), (std::ptr::addr_of_mut!(outputs)));
  rc = tmp_id_170;
  if (rc < (4 as libc::c_int)) {
    tmp_id_171 = (1 as libc::c_int);
  } else {
    tmp_id_172 = __error();
    tmp_id_171 = (((*DEREFtmp_id_172) != (0 as libc::c_int)) as bool);
  }
  if tmp_id_171 {
    perror(__stringlit_2);
    return ((0 as libc::c_int) as *mut libc::c_void);
  }
  tmp_id_173 = genann_init(inputs, hidden_layers, hidden, outputs);
  ann = tmp_id_173;
  i = (0 as libc::c_int);
  'lbl_0: loop {
    if !((i < (*DEREFann).total_weights)) {
      break 'lbl_0;
    }
    tmp_id_174 = __error();
    (*DEREFtmp_id_174) = (0 as libc::c_int);
    tmp_id_175 = fscanf(in, __stringlit_3, ((*DEREFann).weight + i));
    rc = tmp_id_175;
    if (rc < (1 as libc::c_int)) {
      tmp_id_176 = (1 as libc::c_int);
    } else {
      tmp_id_177 = __error();
      tmp_id_176 = (((*DEREFtmp_id_177) != (0 as libc::c_int)) as bool);
    }
    if tmp_id_176 {
      perror(__stringlit_2);
      genann_free(ann);
      return ((0 as libc::c_int) as *mut libc::c_void);
    }
    i = (i + (1 as libc::c_int));
  }
  return ann;
}

#[no_mangle]
pub unsafe extern "C" fn genann_copy(ann : *mut genann) -> *mut genann
{
  let mut size : libc::c_int;
  let mut ret : *mut genann;
  let mut tmp_id_169 : *mut libc::c_void;
  size =
    ((std::mem::sizeof::<genann>() as libc::c_ulonglong) + ((std::mem::sizeof::<libc::c_double>() as libc::c_ulonglong) * (((*DEREFann).total_weights + (*DEREFann).total_neurons) + ((*DEREFann).total_neurons - (*DEREFann).inputs))));
  tmp_id_169 = malloc(size);
  ret = tmp_id_169;
  if !ret {
    return (0 as libc::c_int);
  }
  memcpy(ret, ann, size);
  (*DEREFret).weight =
    (((ret as *mut libc::c_schar) + (std::mem::sizeof::<genann>() as libc::c_ulonglong)) as *mut libc::c_double);
  (*DEREFret).output = ((*DEREFret).weight + (*DEREFret).total_weights);
  (*DEREFret).delta = ((*DEREFret).output + (*DEREFret).total_neurons);
  return ret;
}

#[no_mangle]
pub unsafe extern "C" fn genann_randomize(ann : *mut genann) -> libc::c_void
{
  let mut i : libc::c_int;
  let mut r : libc::c_double;
  let mut tmp_id_169 : libc::c_int;
  i = (0 as libc::c_int);
  'lbl_0: loop {
    if !((i < (*DEREFann).total_weights)) {
      break 'lbl_0;
    }
    tmp_id_169 = rand();
    r = ((tmp_id_169 as libc::c_double) / (2147483647 as libc::c_int));
    (*DEREF((*DEREFann).weight + i)) = (r - (0.5 as libc::c_double));
    i = (i + (1 as libc::c_int));
  }
}

#[no_mangle]
pub unsafe extern "C" fn genann_free(ann : *mut genann) -> libc::c_void
{
  free(ann);
}

#[no_mangle]
pub unsafe extern "C" fn genann_run(ann : *mut genann, inputs : *mut libc::c_double) -> *mut libc::c_double
{
  let mut w : *mut libc::c_double;
  let mut o : *mut libc::c_double;
  let mut i : *mut libc::c_double;
  let mut h : libc::c_int;
  let mut j : libc::c_int;
  let mut k : libc::c_int;
  let mut act : *mut (fn(libc::c_double) -> libc::c_double);
  let mut acto : *mut (fn(libc::c_double) -> libc::c_double);
  let mut sum : libc::c_double;
  let mut ret : *mut libc::c_double;
  let mut sum__1 : libc::c_double;
  let mut tmp_id_179 : libc::c_double;
  let mut tmp_id_178 : *mut libc::c_double;
  let mut tmp_id_177 : *mut libc::c_double;
  let mut tmp_id_176 : libc::c_int;
  let mut tmp_id_175 : *mut libc::c_double;
  let mut tmp_id_174 : libc::c_int;
  let mut tmp_id_173 : libc::c_double;
  let mut tmp_id_172 : *mut libc::c_double;
  let mut tmp_id_171 : *mut libc::c_double;
  let mut tmp_id_170 : libc::c_int;
  let mut tmp_id_169 : *mut libc::c_double;
  w = (*DEREFann).weight;
  o = ((*DEREFann).output + (*DEREFann).inputs);
  i = (*DEREFann).output;
  memcpy
    ((*DEREFann).output, inputs, ((std::mem::sizeof::<libc::c_double>() as libc::c_ulonglong) * (*DEREFann).inputs));
  act = (*DEREFann).activation_hidden;
  acto = (*DEREFann).activation_output;
  h = (0 as libc::c_int);
  'lbl_0: loop {
    if !((h < (*DEREFann).hidden_layers)) {
      break 'lbl_0;
    }
    j = (0 as libc::c_int);
    'lbl_1: loop {
      if !((j < (*DEREFann).hidden)) {
        break 'lbl_1;
      }
      tmp_id_169 = w;
      w = (tmp_id_169 + (1 as libc::c_int));
      sum = ((*DEREFtmp_id_169) * -(1 as libc::c_double));
      k = (0 as libc::c_int);
      'lbl_2: loop {
        if (h == (0 as libc::c_int)) {
          tmp_id_170 = ((*DEREFann).inputs as libc::c_int);
        } else {
          tmp_id_170 = ((*DEREFann).hidden as libc::c_int);
        }
        if !((k < tmp_id_170)) {
          break 'lbl_2;
        }
        tmp_id_171 = w;
        w = (tmp_id_171 + (1 as libc::c_int));
        sum = (sum + ((*DEREFtmp_id_171) * (*DEREF(i + k))));
        k = (k + (1 as libc::c_int));
      }
      tmp_id_172 = o;
      o = (tmp_id_172 + (1 as libc::c_int));
      tmp_id_173 = act(sum);
      (*DEREFtmp_id_172) = tmp_id_173;
      j = (j + (1 as libc::c_int));
    }
    if (h == (0 as libc::c_int)) {
      tmp_id_174 = ((*DEREFann).inputs as libc::c_int);
    } else {
      tmp_id_174 = ((*DEREFann).hidden as libc::c_int);
    }
    i = (i + tmp_id_174);
    h = (h + (1 as libc::c_int));
  }
  ret = o;
  j = (0 as libc::c_int);
  'lbl_0: loop {
    if !((j < (*DEREFann).outputs)) {
      break 'lbl_0;
    }
    tmp_id_175 = w;
    w = (tmp_id_175 + (1 as libc::c_int));
    sum__1 = ((*DEREFtmp_id_175) * -(1 as libc::c_double));
    k = (0 as libc::c_int);
    'lbl_1: loop {
      if (*DEREFann).hidden_layers {
        tmp_id_176 = ((*DEREFann).hidden as libc::c_int);
      } else {
        tmp_id_176 = ((*DEREFann).inputs as libc::c_int);
      }
      if !((k < tmp_id_176)) {
        break 'lbl_1;
      }
      tmp_id_177 = w;
      w = (tmp_id_177 + (1 as libc::c_int));
      sum__1 = (sum__1 + ((*DEREFtmp_id_177) * (*DEREF(i + k))));
      k = (k + (1 as libc::c_int));
    }
    tmp_id_178 = o;
    o = (tmp_id_178 + (1 as libc::c_int));
    tmp_id_179 = acto(sum__1);
    (*DEREFtmp_id_178) = tmp_id_179;
    j = (j + (1 as libc::c_int));
  }
  if !(((w - (*DEREFann).weight) == (*DEREFann).total_weights)) {
    printf
      (__stringlit_6, __stringlit_5, (227 as libc::c_int), __stringlit_4);
    abort();
  }
  if !(((o - (*DEREFann).output) == (*DEREFann).total_neurons)) {
    printf
      (__stringlit_6, __stringlit_5, (228 as libc::c_int), __stringlit_7);
    abort();
  }
  return ret;
}

#[no_mangle]
pub unsafe extern "C" fn genann_train(ann : *mut genann, inputs : *mut libc::c_double, desired_outputs : *mut libc::c_double, learning_rate : libc::c_double) -> libc::c_void
{
  let mut h : libc::c_int;
  let mut j : libc::c_int;
  let mut k : libc::c_int;
  let mut o : *mut libc::c_double;
  let mut d : *mut libc::c_double;
  let mut t : *mut libc::c_double;
  let mut o__1 : *mut libc::c_double;
  let mut d__1 : *mut libc::c_double;
  let mut dd : *mut libc::c_double;
  let mut ww : *mut libc::c_double;
  let mut delta : libc::c_double;
  let mut forward_delta : libc::c_double;
  let mut windex : libc::c_int;
  let mut forward_weight : libc::c_double;
  let mut d__2 : *mut libc::c_double;
  let mut w : *mut libc::c_double;
  let mut i : *mut libc::c_double;
  let mut d__3 : *mut libc::c_double;
  let mut i__1 : *mut libc::c_double;
  let mut w__1 : *mut libc::c_double;
  let mut tmp_id_183 : *mut libc::c_double;
  let mut tmp_id_182 : *mut libc::c_double;
  let mut tmp_id_181 : libc::c_int;
  let mut tmp_id_180 : libc::c_int;
  let mut tmp_id_179 : libc::c_int;
  let mut tmp_id_178 : *mut libc::c_double;
  let mut tmp_id_177 : *mut libc::c_double;
  let mut tmp_id_176 : libc::c_int;
  let mut tmp_id_175 : libc::c_int;
  let mut tmp_id_174 : libc::c_int;
  let mut tmp_id_173 : libc::c_int;
  let mut tmp_id_172 : *mut libc::c_double;
  let mut tmp_id_171 : *mut libc::c_double;
  let mut tmp_id_170 : *mut libc::c_double;
  let mut tmp_id_169 : *mut libc::c_double;
  printf
    (__stringlit_8, (std::ptr::addr_of_mut!(genann_run)), (420 as libc::c_int));
  genann_run(ann, inputs);
  o =
    (((*DEREFann).output + (*DEREFann).inputs) + ((*DEREFann).hidden * (*DEREFann).hidden_layers));
  d = ((*DEREFann).delta + ((*DEREFann).hidden * (*DEREFann).hidden_layers));
  t = desired_outputs;
  if ((*DEREFann).activation_output == genann_act_linear) {
    j = (0 as libc::c_int);
    'lbl_0: loop {
      if !((j < (*DEREFann).outputs)) {
        break 'lbl_0;
      }
      tmp_id_169 = d;
      d = (tmp_id_169 + (1 as libc::c_int));
      tmp_id_170 = t;
      t = (tmp_id_170 + (1 as libc::c_int));
      tmp_id_171 = o;
      o = (tmp_id_171 + (1 as libc::c_int));
      (*DEREFtmp_id_169) = ((*DEREFtmp_id_170) - (*DEREFtmp_id_171));
      j = (j + (1 as libc::c_int));
    }
  } else {
    j = (0 as libc::c_int);
    'lbl_0: loop {
      if !((j < (*DEREFann).outputs)) {
        break 'lbl_0;
      }
      tmp_id_172 = d;
      d = (tmp_id_172 + (1 as libc::c_int));
      (*DEREFtmp_id_172) =
        ((((*DEREFt) - (*DEREFo)) * (*DEREFo)) * ((1 as libc::c_double) - (*DEREFo)));
      o = (o + (1 as libc::c_int));
      t = (t + (1 as libc::c_int));
      j = (j + (1 as libc::c_int));
    }
  }
  h = ((*DEREFann).hidden_layers - (1 as libc::c_int));
  'lbl_0: loop {
    if !((h >= (0 as libc::c_int))) {
      break 'lbl_0;
    }
    o__1 =
      (((*DEREFann).output + (*DEREFann).inputs) + (h * (*DEREFann).hidden));
    d__1 = ((*DEREFann).delta + (h * (*DEREFann).hidden));
    dd =
      ((*DEREFann).delta + ((h + (1 as libc::c_int)) * (*DEREFann).hidden));
    ww =
      (((*DEREFann).weight + (((*DEREFann).inputs + (1 as libc::c_int)) * (*DEREFann).hidden)) + ((((*DEREFann).hidden + (1 as libc::c_int)) * (*DEREFann).hidden) * h));
    j = (0 as libc::c_int);
    'lbl_1: loop {
      if !((j < (*DEREFann).hidden)) {
        break 'lbl_1;
      }
      delta = (0 as libc::c_int);
      k = (0 as libc::c_int);
      'lbl_2: loop {
        if (h == ((*DEREFann).hidden_layers - (1 as libc::c_int))) {
          tmp_id_173 = ((*DEREFann).outputs as libc::c_int);
        } else {
          tmp_id_173 = ((*DEREFann).hidden as libc::c_int);
        }
        if !((k < tmp_id_173)) {
          break 'lbl_2;
        }
        forward_delta = (*DEREF(dd + k));
        windex =
          ((k * ((*DEREFann).hidden + (1 as libc::c_int))) + (j + (1 as libc::c_int)));
        forward_weight = (*DEREF(ww + windex));
        delta = (delta + (forward_delta * forward_weight));
        k = (k + (1 as libc::c_int));
      }
      (*DEREFd__1) =
        (((*DEREFo__1) * ((1 as libc::c_double) - (*DEREFo__1))) * delta);
      d__1 = (d__1 + (1 as libc::c_int));
      o__1 = (o__1 + (1 as libc::c_int));
      j = (j + (1 as libc::c_int));
    }
    h = (h - (1 as libc::c_int));
  }
  d__2 =
    ((*DEREFann).delta + ((*DEREFann).hidden * (*DEREFann).hidden_layers));
  if (*DEREFann).hidden_layers {
    tmp_id_174 =
      (((((*DEREFann).inputs + (1 as libc::c_int)) * (*DEREFann).hidden) + ((((*DEREFann).hidden + (1 as libc::c_int)) * (*DEREFann).hidden) * ((*DEREFann).hidden_layers - (1 as libc::c_int)))) as libc::c_int);
  } else {
    tmp_id_174 = ((0 as libc::c_int) as libc::c_int);
  }
  w = ((*DEREFann).weight + tmp_id_174);
  if (*DEREFann).hidden_layers {
    tmp_id_175 =
      (((*DEREFann).inputs + ((*DEREFann).hidden * ((*DEREFann).hidden_layers - (1 as libc::c_int)))) as libc::c_int);
  } else {
    tmp_id_175 = ((0 as libc::c_int) as libc::c_int);
  }
  i = ((*DEREFann).output + tmp_id_175);
  j = (0 as libc::c_int);
  'lbl_0: loop {
    if !((j < (*DEREFann).outputs)) {
      break 'lbl_0;
    }
    k = (0 as libc::c_int);
    'lbl_1: loop {
      if (*DEREFann).hidden_layers {
        tmp_id_176 = ((*DEREFann).hidden as libc::c_int);
      } else {
        tmp_id_176 = ((*DEREFann).inputs as libc::c_int);
      }
      if !((k < (tmp_id_176 + (1 as libc::c_int)))) {
        break 'lbl_1;
      }
      if (k == (0 as libc::c_int)) {
        tmp_id_177 = w;
        w = (tmp_id_177 + (1 as libc::c_int));
        (*DEREFtmp_id_177) =
          ((*DEREFtmp_id_177) + (((*DEREFd__2) * learning_rate) * -(1 as libc::c_double)));
      } else {
        tmp_id_178 = w;
        w = (tmp_id_178 + (1 as libc::c_int));
        (*DEREFtmp_id_178) =
          ((*DEREFtmp_id_178) + (((*DEREFd__2) * learning_rate) * (*DEREF(i + (k - (1 as libc::c_int))))));
      }
      k = (k + (1 as libc::c_int));
    }
    d__2 = (d__2 + (1 as libc::c_int));
    j = (j + (1 as libc::c_int));
  }
  if !(((w - (*DEREFann).weight) == (*DEREFann).total_weights)) {
    printf
      (__stringlit_6, __stringlit_5, (321 as libc::c_int), __stringlit_4);
    abort();
  }
  h = ((*DEREFann).hidden_layers - (1 as libc::c_int));
  'lbl_0: loop {
    if !((h >= (0 as libc::c_int))) {
      break 'lbl_0;
    }
    d__3 = ((*DEREFann).delta + (h * (*DEREFann).hidden));
    if h {
      tmp_id_179 =
        (((*DEREFann).inputs + ((*DEREFann).hidden * (h - (1 as libc::c_int)))) as libc::c_int);
    } else {
      tmp_id_179 = ((0 as libc::c_int) as libc::c_int);
    }
    i__1 = ((*DEREFann).output + tmp_id_179);
    if h {
      tmp_id_180 =
        (((((*DEREFann).inputs + (1 as libc::c_int)) * (*DEREFann).hidden) + ((((*DEREFann).hidden + (1 as libc::c_int)) * (*DEREFann).hidden) * (h - (1 as libc::c_int)))) as libc::c_int);
    } else {
      tmp_id_180 = ((0 as libc::c_int) as libc::c_int);
    }
    w__1 = ((*DEREFann).weight + tmp_id_180);
    j = (0 as libc::c_int);
    'lbl_1: loop {
      if !((j < (*DEREFann).hidden)) {
        break 'lbl_1;
      }
      k = (0 as libc::c_int);
      'lbl_2: loop {
        if (h == (0 as libc::c_int)) {
          tmp_id_181 = ((*DEREFann).inputs as libc::c_int);
        } else {
          tmp_id_181 = ((*DEREFann).hidden as libc::c_int);
        }
        if !((k < (tmp_id_181 + (1 as libc::c_int)))) {
          break 'lbl_2;
        }
        if (k == (0 as libc::c_int)) {
          tmp_id_182 = w__1;
          w__1 = (tmp_id_182 + (1 as libc::c_int));
          (*DEREFtmp_id_182) =
            ((*DEREFtmp_id_182) + (((*DEREFd__3) * learning_rate) * -(1 as libc::c_double)));
        } else {
          tmp_id_183 = w__1;
          w__1 = (tmp_id_183 + (1 as libc::c_int));
          (*DEREFtmp_id_183) =
            ((*DEREFtmp_id_183) + (((*DEREFd__3) * learning_rate) * (*DEREF(i__1 + (k - (1 as libc::c_int))))));
        }
        k = (k + (1 as libc::c_int));
      }
      d__3 = (d__3 + (1 as libc::c_int));
      j = (j + (1 as libc::c_int));
    }
    h = (h - (1 as libc::c_int));
  }
}

#[no_mangle]
pub unsafe extern "C" fn genann_write(ann : *mut genann, out : *mut __sFILE) -> libc::c_void
{
  let mut i : libc::c_int;
  fprintf
    (out, __stringlit_1, (*DEREFann).inputs, (*DEREFann).hidden_layers, (*DEREFann).hidden, (*DEREFann).outputs);
  i = (0 as libc::c_int);
  'lbl_0: loop {
    if !((i < (*DEREFann).total_weights)) {
      break 'lbl_0;
    }
    fprintf(out, __stringlit_9, (*DEREF((*DEREFann).weight + i)));
    i = (i + (1 as libc::c_int));
  }
}


