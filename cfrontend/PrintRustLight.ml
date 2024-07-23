open Format
open! Ctypes
open AST
open Camlcoq (*for extern_atom*)
open RustLight
(*open Camlcoq
open PrintAST
open Ctypes
open Cop
open PrintCsyntax
open Clight*)
(* open RustLight *)

  (* let lt = Unbounded in *)
  (* match lt with *)
  (* | Unbounded -> fprintf p "@[<v 0> It works hello world @]@wtwasdfjaksdfkjsdkjasdjfkasdfajsdkfaa\n\n\n\n\n\n\n" *)
  (* | Bounded (_, _) -> fprintf p "It extra works hello world\n" *)

let destination : string option ref = ref None

let define_composite p (Composite(id, su, m, a)) = ()


let name_inttype_rust sz sg =
  match sz, sg with
  | I8, Signed -> "libc::c_schar"
  | I8, Unsigned -> "libc::c_uchar"
  | I16, Signed -> "libc::c_short"
  | I16, Unsigned -> "libc::c_ushort"
  | I32, Signed -> "libc::c_int"
  | I32, Unsigned -> "libc::c_uint"
  (* using bool here, unsure of corretness *)
  | IBool, _ -> "bool"

let rec gen_ty_rust ty =
  match ty with
  | Ctypes.Tvoid -> "libc::c_void"
  | Ctypes.Tint(sz, sg, a) ->
    (* TODO ignoring the attributes for now. The volatile should be handled a layer up probably. Same for align? Either way going for the easy thing *)
    (* TODO deal with visibility modifier *)
    name_inttype_rust sz sg
  | Ctypes.Tarray(ity, num_ele, attrs) ->
    let fmted_ity = gen_ty_rust ity in
    sprintf "[ %s; %ld]"  fmted_ity (camlint_of_coqint num_ele)
  | _ -> "unimplemented!"

let gen_name_and_ty_rust name ty = name ^ " : " ^ (gen_ty_rust ty)

let print_primitive_init fmt = function
  | Init_int8 n -> fprintf fmt"%ld" (camlint_of_coqint n)
  | Init_int16 n -> fprintf fmt "%ld" (camlint_of_coqint n)
  | Init_int32 n -> fprintf fmt "%ld" (camlint_of_coqint n)
  | Init_int64 n -> fprintf fmt "%LdLL" (camlint64_of_coqint n)
  | Init_float32 n -> fprintf fmt "%.15F" (camlfloat_of_coqfloat n)
  | Init_float64 n -> fprintf fmt "%.15F" (camlfloat_of_coqfloat n)
  | Init_space n -> fprintf fmt "/* skip %s */@ " (Z.to_string n)
  | Init_addrof(symb, ofs) -> () (* TODO *)
      (* let ofs = camlint_of_coqint ofs in *)
      (* if ofs = 0l *)
      (* then fprintf p "&%s" (extern_atom symb) *)
      (* else fprintf p "(void *\)((char *\)&%s + %ld)" (extern_atom symb) ofs *)

let print_globvar fmt id v =
  let name_bare = extern_atom id in
  (* TODO deal with extern. Can't just assume it's const or static *)

  (* need to do static analysis pass to conclude that this is actually static mut *)
  (* in rust, const a : u32 = 5; ensure (with the compiler) that a is not writable. Ever *)
  (* in c, const int a = 5; void f(){ *(&a) = 6; } works just fine*)

  (* TODO if static in C, should become `pub` here *)
  let name = "static mut "^name_bare in
  match v.gvar_init with
  (* no data, declared somewhere else *)
  | [] -> ()
    (* morally speaking, want a use statement *)
    (* we DONT need to redeclare it *)
    (* this means we need to track the crates (and generate a lib.rs) *)
    (* not there yet, however. *)
    (* so, do nothing. *)
    (* fprintf fmt "extern %s; @ @ " name; *)
  | [Init_space _] ->
    (* TODO pretty sure this is not right  *)
    fprintf fmt "%s; @ @ " (gen_name_and_ty_rust name v.gvar_info)
  | _ ->
    fprintf fmt "@[<hov 2>%s = " (gen_name_and_ty_rust name v.gvar_info);
    begin match v.gvar_info, v.gvar_init with
      | (Ctypes.Tint _ | Ctypes.Tlong _ | Ctypes.Tfloat _ | Tpointer _ | Tfunction _),
        [i1] -> print_primitive_init fmt i1
      | _, il -> ()
    end;
  fprintf fmt ";@]@ @ "

(* fn name(param: ty, ) -> { body  }*)
let print_function fmt id fn =
  let fn_name = (extern_atom id) in
  let fn_params = fn.fn_params in
  let fn_args = List.fold_left (fun acc (tid, tty) -> acc ^ (gen_name_and_ty_rust (extern_atom tid) tty) ^ ", ") ("") fn_params in
  (* let params = name_function_parameters extern_atom (extern_atom id) f.fn_params f.fn_callconv in *)
  (* TODO deal with visibility modifier *)
  fprintf fmt "fn %s(%s)" fn_name fn_args
  (* print name of function *)




let print_fundef fmt id fundef =
  match fundef with
  | Ctypes.Internal f -> print_function fmt id f
  (* don't need extern to be printed. However, do need use*)
  (* TODO print use keyword here *)
  | Ctypes.External(_, _, _, _) ->  ()


let print_globdef fmt (id, gd) =
  match gd with
  | Gfun fundef -> print_fundef fmt id fundef
  | Gvar v -> print_globvar fmt id v

let print_program f (prog: RustLight.r_program) =
  let [@warning "-42"] p_types = prog.prog_types in
  let [@warning "-42"] p_defs = prog.prog_defs in
  fprintf f "@[<v 0>";
  List.iter (define_composite f) p_types;
  List.iter (print_globdef f) p_defs;
  fprintf f "@]@."

let print_if (_, prog) =
  match !destination with
  | None -> ()
    (* printf "%s" "Camels\n"; *)
  | Some f ->
    let oc = open_out f in
    print_program (formatter_of_out_channel oc) prog;
    close_out oc;
