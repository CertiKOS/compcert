(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(*          Xavier Leroy, INRIA Paris-Rocquencourt                     *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the INRIA Non-Commercial License Agreement.     *)
(*                                                                     *)
(* *********************************************************************)

open Printf
open Commandline
open Clflags
open CommonOptions
open Timing
open Driveraux
open Frontend
open Assembler
open Linker
open Diagnostics

(* Name used for version string etc. *)
let tool_name = "C verified compiler"

let sym_mapping : ((string, string) Hashtbl.t) ref = ref (Hashtbl.create 7)

(* struct or union ident -> (file, defn) option  *)
let composite_mapping: ((string, ((string * Ctypes.composite_definition) option)) Hashtbl.t) ref = ref (Hashtbl.create 7)

(* Optional sdump suffix *)
let sdump_suffix = ref ".json"

let nolink () =
  !option_c || !option_S || !option_E || !option_interp

let object_filename sourcename =
  if nolink () then
    output_filename ~final: !option_c sourcename ~suffix:".o"
  else
    tmp_file ".o"


let extract_globals sourcename =
  ensure_inputfile_exists sourcename;
  (* printf "\nPTYPES: %s\n" sourcename; *)
  let preproname = tmp_file ".i" in
  preprocess sourcename preproname;
  let csyntax = parse_c_file sourcename preproname in
  Compiler.get_exports csyntax

let convert_mapping (tbl : (string, string) Hashtbl.t) : (char list * char list) list =
  Hashtbl.fold
    (fun key value acc ->
      (String.to_seq key |> List.of_seq, String.to_seq value |> List.of_seq) :: acc)
    tbl
    []

let convert_mapping1 (tbl: (string, (string * Ctypes.composite_definition) option) Hashtbl.t) =
  Hashtbl.fold (
    fun key opt acc ->
      match opt with
      | Some ((v, dfn)) -> (String.to_seq key |> List.of_seq, Some ((String.to_seq v |> List.of_seq), dfn)) :: acc
      | None -> (String.to_seq key |> List.of_seq, None) :: acc
  ) tbl []

(* From CompCert C AST to asm *)

let compile_c_file sourcename ifile ofile =
  (*  *set the destinations (e.g. pointers) if we want to print *)

  (* Prepare to dump Clight, RTL, etc, if requested *)
  let set_dest dst opt ext =
    dst := if !opt then Some (output_filename sourcename ~suffix:ext)
      else None in
  set_dest Cprint.destination option_dparse ".parsed.c";
  set_dest PrintCsyntax.destination option_dcmedium ".compcert.c";
  set_dest PrintClight.destination option_dclight ".light.c";
  set_dest PrintRustLight.destination option_drustlight ".rs";
  set_dest PrintCminor.destination option_dcminor ".cm";
  set_dest PrintRTL.destination option_drtl ".rtl";
  set_dest Regalloc.destination_alloctrace option_dalloctrace ".alloctrace";
  set_dest PrintLTL.destination option_dltl ".ltl";
  set_dest PrintMach.destination option_dmach ".mach";
  (*  TODO add in pass for drust*)
  set_dest AsmToJSON.destination option_sdump !sdump_suffix;
  (* Parse the ast *)
  let csyntax = parse_c_file sourcename ifile in
  let regular_sym_mapping = convert_mapping !sym_mapping in
  let regular_composite_mapping = convert_mapping1 !composite_mapping in

  let module_name = String.sub sourcename 0 ((String.length sourcename) - 2) in

  match (Compiler.print_r_program regular_sym_mapping regular_composite_mapping (String.to_seq module_name |> List.of_seq) csyntax) with
  | Errors.OK _rprog -> printf "translated!"
  | Errors.Error msg -> printf "error! %s" (C2C.string_of_errmsg msg)
  ;
  (* (1) call out to transf_rust_program *)
  (* (2)  *)
  (* (3)  *)
  (* (4)  *)

  (*let maybe_rust = Compiler.transf_clight_program_to_rust csyntax in
  match maybe_rust with
  | Errors.OK rustsyntax -> ()
  | Errors.Error msg -> ()
    ;*)


  (* Convert to Asm *)
  (* this calls out to compiler.v::transf_c_program*)
  (* which calls transf_clight_program *)
  (* which calls print_clight *)
  (* which is bound to PrintClight.print_if *)
  (* which knows which file to print to because we just set the destination *)
  let asm =
    match Compiler.apply_partial
               (Compiler.transf_c_program csyntax)
               Asmexpand.expand_program with
    | Errors.OK asm ->
        asm
    | Errors.Error msg ->
      let loc = file_loc sourcename in
        fatal_error loc "%a"  print_error msg in
  (* Dump Asm in binary and JSON format *)
  AsmToJSON.print_if asm sourcename;
  (* Print Asm in text form *)
  let oc = open_out ofile in
  PrintAsm.print_program oc asm;
  close_out oc

(* From C source to asm *)

let compile_i_file sourcename preproname =
  printf"\nCOMPILE_I IS CALLED\n";
  if !option_interp then begin
    Machine.config := Machine.compcert_interpreter !Machine.config;
    let csyntax = parse_c_file sourcename preproname in
    Interp.execute csyntax;
        ""
  end else if !option_S then begin
    compile_c_file sourcename preproname
      (output_filename ~final:true sourcename ~suffix:".s");
    ""
  end else begin
    let asmname =
      if !option_dasm
      then output_filename sourcename ~suffix:".s"
      else tmp_file ".s" in
    compile_c_file sourcename preproname asmname;
    let objname = object_filename sourcename  in
    assemble asmname objname;
    objname
  end

let create_directory dir_name =
try
  Unix.mkdir dir_name 0o755;  (* 0o755 is the permission code *)
  Printf.printf "Directory '%s' created successfully.\n" dir_name
with
| Unix.Unix_error (err, _, _) ->
  Printf.printf "\nError creating directory: %s with error %s\n\n" dir_name (Unix.error_message err)

(* Processing of a .c file *)

let process_c_file sourcename =
  printf"\nPROCESS_C IS CALLED\n";
  ensure_inputfile_exists sourcename;
  if !option_E then begin
    preprocess sourcename (output_filename_default "-");
    ""
  end else begin
    let preproname = if !option_dprepro then
      output_filename sourcename ~suffix:".i"
    else
      tmp_file ".i" in

    preprocess sourcename preproname;
    compile_i_file sourcename preproname
  end

(* Processing of a .i / .p file (preprocessed C) *)

let process_i_file sourcename =
  ensure_inputfile_exists sourcename;
  compile_i_file sourcename sourcename

(* Processing of .S and .s files *)

let process_s_file sourcename =
  ensure_inputfile_exists sourcename;
  let objname = object_filename sourcename in
  assemble sourcename objname;
  objname

let process_S_file sourcename =
  ensure_inputfile_exists sourcename;
  if !option_E then begin
    preprocess sourcename (output_filename_default "-");
    ""
  end else begin
    let preproname = tmp_file ".s" in
    preprocess sourcename preproname;
    let objname = object_filename sourcename in
    assemble preproname objname;
    objname
  end

(* Processing of .h files *)

let process_h_file sourcename =
  if !option_E then begin
    ensure_inputfile_exists sourcename;
    preprocess sourcename (output_filename_default "-");
    ""
  end else
    fatal_error no_loc "input file %s ignored (not in -E mode)\n" sourcename

let target_help =
  if Configuration.arch = "arm" && Configuration.model <> "armv6" then
{|Target processor options:
  -mthumb        Use Thumb2 instruction encoding
  -marm          Use classic ARM instruction encoding
|}
else
  ""

let toolchain_help =
  if not Configuration.gnu_toolchain then begin
{|Toolchain options:
  -t tof:env     Select target processor for the diab toolchain
|} end else
    ""

let usage_string =
  version_string tool_name ^
  {|Usage: ccomp [options] <source files>
Recognized source files:
  .c             C source file
  .i or .p       C source file that should not be preprocessed
  .s             Assembly file
  .S or .sx      Assembly file that must be preprocessed
  .o             Object file
  .a             Library file
Processing options:
  -c             Compile to object file only (no linking), result in <file>.o
  -E             Preprocess only, send result to standard output
  -S             Compile to assembler only, save result in <file>.s
  -o <file>      Generate output in <file>
|} ^
  prepro_help ^
  language_support_help ^
 DebugInit.debugging_help ^
{|Optimization options: (use -fno-<opt> to turn off -f<opt>)
  -O             Optimize the compiled code [on by default]
  -O0            Do not optimize the compiled code
  -O1 -O2 -O3    Synonymous for -O
  -Os            Optimize for code size in preference to code speed
  -Obranchless   Optimize to generate fewer conditional branches; try to produce
                 branch-free instruction sequences as much as possible
  -ftailcalls    Optimize function calls in tail position [on]
  -fconst-prop   Perform global constant propagation  [on]
  -ffloat-const-prop <n>  Control constant propagation of floats
                   (<n>=0: none, <n>=1: limited, <n>=2: full; default is full)
  -fcse          Perform common subexpression elimination [on]
  -fredundancy   Perform redundancy elimination [on]
  -finline       Perform inlining of functions [on]
  -finline-functions-called-once Integrate functions only required by their
                 single caller [on]
  -fif-conversion Perform if-conversion (generation of conditional moves) [on]
Code generation options: (use -fno-<opt> to turn off -f<opt>)
  -ffpu          Use FP registers for some integer operations [on]
  -fsmall-data <n>  Set maximal size <n> for allocation in small data area
  -fsmall-const <n>  Set maximal size <n> for allocation in small constant area
  -falign-functions <n>  Set alignment (in bytes) of function entry points
  -falign-branch-targets <n>  Set alignment (in bytes) of branch targets
  -falign-cond-branches <n>  Set alignment (in bytes) of conditional branches
  -fcommon       Put uninitialized globals in the common section [on].
|} ^
 target_help ^
 toolchain_help ^
 assembler_help ^
 linker_help ^
{|Tracing options:
  -dprepro       Save C file after preprocessing in <file>.i
  -dparse        Save C file after parsing and elaboration in <file>.parsed.c
  -dc            Save generated Compcert C in <file>.compcert.c
  -dclight       Save generated Clight in <file>.light.c
  -dcminor       Save generated Cminor in <file>.cm
  -drtl          Save RTL at various optimization points in <file>.rtl.<n>
  -dltl          Save LTL after register allocation in <file>.ltl
  -dmach         Save generated Mach code in <file>.mach
  -drustlight    Save generated Rust code in <file>.rs
  -drustproj     Save generated Rust code in rust project. Use in conjunction with drustlight.
  -dasm          Save generated assembly in <file>.s
  -dall          Save all generated intermediate files in <file>.<ext>
  -sdump         Save info for post-linking validation in <file>.json
|} ^
  general_help ^
  warning_help ^
  {|Interpreter mode:
  -interp        Execute given .c files using the reference interpreter
  -quiet         Suppress diagnostic messages for the interpreter
  -trace         Have the interpreter produce a detailed trace of reductions
  -random        Randomize execution order
  -all           Simulate all possible execution orders
  -main <name>   Start executing at function <name> instead of main()
|}

let print_usage_and_exit () =
  printf "%s" usage_string; exit 0

let dump_mnemonics destfile =
  let oc = open_out_bin destfile in
  let pp = Format.formatter_of_out_channel oc in
  AsmToJSON.pp_mnemonics pp;
  Format.pp_print_flush pp ();
  close_out oc;
  exit 0

let optimization_options = [
  option_ftailcalls; option_fifconversion; option_fconstprop; option_fcse;
  option_fredundancy; option_finline; option_finline_functions_called_once;
]

let set_all opts () = List.iter (fun r -> r := true) opts
let unset_all opts () = List.iter (fun r -> r := false) opts

let num_source_files = ref 0

let num_input_files = ref 0

let list_c_files = ref ([])

let t_conv_fn = fun cl -> String.of_seq (List.to_seq cl)

let char_list_list_to_string_list (cll : char list list) : string list =
  List.map t_conv_fn cll

let print_string_list lst =
  print_string "[";
  List.iter (fun x -> Printf.printf "\"%s\"; " x) lst;
  print_string "]\n"

let add_to_list file = list_c_files := !list_c_files @ [file]

let print_hashtbl tbl =
  printf "UID SYMBOL MAPPING: \n";
  Hashtbl.iter (fun key value -> Printf.printf "UID %s: %s\n" key value) tbl;
  printf "UID END SYMBOL MAPPING\n"

let [@warning "-42"] comp_eq a a_ =
  match a,a_ with
  | Ctypes.Composite (_, sou, mems, attrs), Ctypes.Composite(_, sou_, mems_, attrs_) -> (
      let sou_r =
        match (sou, sou_) with
        | (Ctypes.Union, Ctypes.Union) -> true
        | (Ctypes.Struct, Ctypes.Struct) -> true
        | _ -> false
      in
      let mem_eq_fn = fun m_1 m_2 -> (
          match (m_1, m_2) with
          | Ctypes.Member_plain(_, ty), Ctypes.Member_plain(_, ty') -> ty = ty'
          | Ctypes.Member_bitfield(_, a, b, c, d, e), Ctypes.Member_bitfield(_, a', b', c', d', e') ->
            a = a' && b = b' && c = c' && d = d' && e = e'
          | _ -> false
        )
      in
      let mems_r =
        if (List.length mems) != (List.length mems_) then
          false
        else
          List.fold_left (fun acc (a, b) -> (mem_eq_fn a b) && acc)
            true
            (List.combine mems mems_)
      in
      let attrs_r = attrs = attrs_ in
      sou_r && mems_r && attrs_r
    )

let generate_mapping unit =
  (* symbol -> module in rust that exports it *)
  List.iter
    (fun file_name ->
       let module_name = String.sub file_name 0 ((String.length file_name) - 2) in
       let glob_list = extract_globals file_name in
       (match glob_list with
        | Errors.OK l -> (List.iter
                           (fun symbol ->
                              Hashtbl.add !sym_mapping symbol module_name) (char_list_list_to_string_list (fst l))
                          ;
                          List.iter (fun (sym_chars, dfn) -> (
                              let sym = t_conv_fn sym_chars in
                              match Hashtbl.find_opt !composite_mapping sym with
                              (* first occurence *)
                              | None -> Hashtbl.replace !composite_mapping sym (Some((module_name, dfn)))
                              (* set to none explicitly, do nothing *)
                              | Some (None) -> printf "UUID explicitly setting to NONE\n"; ()
                              | Some (Some (f, dfn_old)) -> (
                                  (* let (sou, mems, attrs) = match dfn with | Ctypes.Composite(_,a,b,c) -> (a, b, c) in *)
                                  (* let (sou_o, mems_o, attrs_o) = match dfn_old with | Ctypes.Composite(_,a,b,c) -> (a, b, c) in *)
                                  if not (comp_eq dfn dfn_old) then
                                    (* printf "sou is struct: %b, sou_o is struct %b" (sou == Ctypes.Struct) (sou_o == Ctypes.Union); *)
                                    (* printf "UUID inequal for %s with %b %b %b, replacing!\n" sym (sou = sou_o) (mems = mems_o) (attrs = attrs_o) ; *)
                                    (Hashtbl.replace !composite_mapping sym None)
                              )
                          )) (snd l))
        | Errors.Error _ -> printf "ERROR making mapping!"; ())

    ) !list_c_files; print_hashtbl !sym_mapping

let cmdline_actions =
  let f_opt name ref =
    [Exact("-f" ^ name), Set ref; Exact("-fno-" ^ name), Unset ref] in
  let check_align n =
    if n <= 0 || ((n land (n - 1)) <> 0) then
      error no_loc "requested alignment %d is not a power of 2" n
    in
  [
(* Getting help *)
  Exact "-help", Unit print_usage_and_exit;
  Exact "--help", Unit print_usage_and_exit;]
(* Getting version info *)
  @ version_options tool_name @
(* Enforcing CompCert build numbers for QSKs and mnemonics dump *)
  (if Version.buildnr <> "" then
     [Exact "-dump-mnemonics", String  dump_mnemonics;]
   else []) @
(* Processing options *)
 [ Exact "-c", Set option_c;
  Exact "-E", Set option_E;
  Exact "-S", Set option_S;
  Exact "-o", String(fun s -> option_o := Some s);
  Prefix "-o", Self (fun s -> let s = String.sub s 2 ((String.length s) - 2) in
                              option_o := Some s);]
  (* Preprocessing options *)
    @ prepro_actions @
  (* Language support options *)
    language_support_options
  (* Debugging options *)
    @ DebugInit.debugging_actions @
(* Code generation options -- more below *)
 [
  Exact "-O0", Unit (unset_all optimization_options);
  Exact "-O", Unit (set_all optimization_options);
  _Regexp "-O[123]$", Unit (set_all optimization_options);
  Exact "-Os", Set option_Osize;
  Exact "-Obranchless", Set option_Obranchless;
  Exact "-fsmall-data", Integer(fun n -> option_small_data := n);
  Exact "-fsmall-const", Integer(fun n -> option_small_const := n);
  Exact "-ffloat-const-prop", Integer(fun n -> option_ffloatconstprop := n);
  Exact "-falign-functions", Integer(fun n -> check_align n; option_falignfunctions := Some n);
  Exact "-falign-branch-targets", Integer(fun n -> check_align n; option_falignbranchtargets := n);
  Exact "-falign-cond-branches", Integer(fun n -> check_align n; option_faligncondbranchs := n);] @
      f_opt "common" option_fcommon @
(* Target processor options *)
  (if Configuration.arch = "arm" then
    if Configuration.model = "armv6" then
      [ Exact "-marm", Ignore ] (* Thumb needs ARMv6T2 or ARMv7 *)
    else
      [ Exact "-mthumb", Set option_mthumb;
        Exact "-marm", Unset option_mthumb; ]
   else []) @
(* Toolchain options *)
    (if not Configuration.gnu_toolchain then
       [Exact "-t", String (fun arg -> push_linker_arg "-t"; push_linker_arg arg;
                             prepro_options := arg :: "-t" :: !prepro_options;
                             assembler_options := arg :: "-t" :: !assembler_options;)]
     else
       []) @
(* Assembling options *)
  assembler_actions @
(* Linking options *)
  linker_actions @
(* Tracing options *)
 [ Exact "-dprepro", Set option_dprepro;
  Exact "-dparse", Set option_dparse;
  Exact "-dc", Set option_dcmedium;
  Exact "-dclight", Set option_dclight;
  Exact "-dcminor", Set option_dcminor;
  Exact "-drtl", Set option_drtl;
  Exact "-dltl", Set option_dltl;
  Exact "-dalloctrace", Set option_dalloctrace;
  Exact "-dmach", Set option_dmach;
  Exact "-drustlight", Set option_drustlight;
  Exact "-drustproj", Set option_drustproj;
  Exact "-dasm", Set option_dasm;
  Exact "-dall", Self (fun _ ->
    option_dprepro := true;
    option_dparse := true;
    option_dcmedium := true;
    option_dclight := true;
    option_dcminor := true;
    option_drtl := true;
    option_dltl := true;
    option_dalloctrace := true;
    option_dmach := true;
    option_dasm := true);
  Exact "-sdump", Set option_sdump;
  Exact "-sdump-suffix", String (fun s -> option_sdump := true; sdump_suffix:= s);
  Exact "-sdump-folder", String (fun s -> AsmToJSON.sdump_folder := s);] @
(* General options *)
   general_options @
(* Diagnostic options *)
  warning_options @
(* Interpreter mode *)
 [ Exact "-interp", Set option_interp;
  Exact "-quiet", Unit (fun () -> Interp.trace := 0);
  Exact "-trace", Unit (fun () -> Interp.trace := 2);
  Exact "-random", Unit (fun () -> Interp.mode := Interp.Random);
  Exact "-all", Unit (fun () -> Interp.mode := Interp.All);
  Exact "-main", String (fun s -> main_function_name := s)
 ]
(* Optimization options *)
(* -f options: come in -f and -fno- variants *)
  @ f_opt "tailcalls" option_ftailcalls
  @ f_opt "if-conversion" option_fifconversion
  @ f_opt "const-prop" option_fconstprop
  @ f_opt "cse" option_fcse
  @ f_opt "redundancy" option_fredundancy
  @ f_opt "inline" option_finline
  @ f_opt "inline-functions-called-once" option_finline_functions_called_once
(* Code generation options *)
  @ f_opt "fpu" option_ffpu
  @ f_opt "sse" option_ffpu (* backward compatibility *)
  @ [
(* Catch options that are not handled *)
  Prefix "-", Self (fun s ->
      fatal_error no_loc "Unknown option `%s'" s);
(* File arguments *)
  Suffix ".c", Self (* the entire function here gets executed *) (fun s ->
      printf "next cmd: %s\n" s; add_to_list s; print_string_list !list_c_files; push_action process_c_file s;
      incr num_source_files; incr num_input_files);
  Suffix ".i", Self (fun s ->
      push_action process_i_file s; incr num_source_files; incr num_input_files);
  Suffix ".p", Self (fun s ->
      push_action process_i_file s; incr num_source_files; incr num_input_files);
  Suffix ".s", Self (fun s ->
      push_action process_s_file s; incr num_source_files; incr num_input_files);
  Suffix ".S", Self (fun s ->
      push_action process_S_file s; incr num_source_files; incr num_input_files);
  Suffix ".sx", Self (fun s ->
      push_action process_S_file s; incr num_source_files; incr num_input_files);
  Suffix ".o", Self (fun s -> push_linker_arg s; incr num_input_files);
  Suffix ".a", Self (fun s -> push_linker_arg s; incr num_input_files);
  (* GCC compatibility: .o.ext files and .so files are also object files *)
  _Regexp ".*\\.o\\.", Self (fun s -> push_linker_arg s; incr num_input_files);
  Suffix ".so", Self (fun s -> push_linker_arg s; incr num_input_files);
  (* GCC compatibility: .h files can be preprocessed with -E *)
  Suffix ".h", Self (fun s ->
      push_action process_h_file s; incr num_source_files; incr num_input_files);
  ]

let create_toml unit =
  let oc = open_out "Cargo.toml" in  (* Open the file for writing *)
  let maybe_bin =
    match Hashtbl.find_opt !sym_mapping "main" with
    | Some main_name ->
{|
[[bin]]
name = "main"
path = "./src/|} ^ main_name ^ ".rs\""
    | None -> ""
  in
  (* TODO is there a less ugly way to do this without carrying the whitespace? *)
  let content = {|
[package]
name = "rust_project"
version = "0.0.0"
edition = "2021"

[dependencies]
libc = "0.2.158"

[lib]
path = "src/lib.rs"

|} ^ maybe_bin
in

  output_string oc content;      (* Write the string to the file *)
  close_out oc

let strip_dot_slash s =
  let prefix = "./" in
  if String.length s >= 2 && String.sub s 0 2 = prefix then
    String.sub s 2 (String.length s - 2)
  else
    s


let create_lib unit =
  let content = List.fold_left
      (fun result file ->
         let module_name = String.sub file 0 ((String.length file) - 2) |> strip_dot_slash in
         result^"\npub mod "^module_name^";\n") "" !list_c_files in
  let oc = open_out "lib.rs" in
  output_string oc content;
  close_out oc


let change_directory dir_name =
  try
    Unix.chdir dir_name;  (* Change the current working directory *)
  with
  | Unix.Unix_error (err, _, _) ->
    Printf.printf "Error changing directory: %s\n" (Unix.error_message err)

let generate_boilerplate_rust unit =
  create_directory "rust_project";
  change_directory "./rust_project";
  create_toml ();
  create_directory "src";
  change_directory "./src";
  create_lib ();
  change_directory "../..";
  ()

let _ =
  try
    Gc.set { (Gc.get()) with
                Gc.minor_heap_size = 524288; (* 512k *)
                Gc.major_heap_increment = 4194304 (* 4M *)
           };
    Printexc.record_backtrace true;
    Frontend.init ();
    parse_cmdline cmdline_actions;
    DebugInit.init (); (* Initialize the debug functions *)
    generate_mapping ();
    let _ = Camlcoq.atom_of_string = (Hashtbl.create 17 : (string, Camlcoq.atom) Hashtbl.t) in
    let _ = Camlcoq.next_atom = ref BinNums.Coq_xH in
    generate_boilerplate_rust ();
    (* print_hashtbl !sym_mapping; *)
    if nolink () && !option_o <> None && !num_source_files >= 2 then
      fatal_error no_loc "ambiguous '-o' option (multiple source files)";
    if !num_input_files = 0 then
      fatal_error no_loc "no input file";
    if not !option_interp && !main_function_name <> "main" then
      fatal_error no_loc "option '-main' requires option '-interp'";
    (* the line below is where all the compilation goes *)
    let _linker_args = time "Total compilation time" perform_actions () in
    check_errors ()
  with
  | Sys_error msg
  | CmdError msg -> error no_loc "%s" msg; exit 2
  | Abort -> error_summary (); exit 2
  | e -> crash e
