(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(*          Xavier Leroy, INRIA Paris-Rocquencourt                     *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the GNU Lesser General Public License as        *)
(*  published by the Free Software Foundation, either version 2.1 of   *)
(*  the License, or  (at your option) any later version.               *)
(*  This file is also distributed under the terms of the               *)
(*  INRIA Non-Commercial License Agreement.                            *)
(*                                                                     *)
(* *********************************************************************)

open Printf
open Commandline
open Clflags
open CommonOptions
open Driveraux
open Frontend
open Diagnostics
open RustLight

(* (\* struct or union ident -> (file, defn) option  *\) *)
let sym_mapping : (str_map_globals) ref = ref (StrMap.empty)

(* struct or union ident -> (file, defn) option  *)
let composite_mapping : (str_map_composites) ref = ref (StrMap.empty)


let list_c_files = ref ([])

let add_to_list file = list_c_files := !list_c_files @ [file]

let print_string_list lst =
  print_string "[";
  List.iter (fun x -> Printf.printf "\"%s\"; " x) lst;
  print_string "]\n"

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

let extract_globals sourcename =
  ensure_inputfile_exists sourcename;
  (* printf "\nPTYPES: %s\n" sourcename; *)
  let preproname = tmp_file ".i" in
  preprocess sourcename preproname;
  let csyntax = parse_c_file sourcename preproname in
  Compiler.get_exports csyntax

let print_hashtbl tbl =
  printf "UID SYMBOL MAPPING: \n";
  Hashtbl.iter (fun key value -> Printf.printf "UID %s: %s\n" key value) tbl;
  printf "UID END SYMBOL MAPPING\n"

let generate_mapping unit =
  (* symbol -> module in rust that exports it *)
  List.iter
    (fun file_name ->
       let module_name = String.sub file_name 0 ((String.length file_name) - 2) |> String.to_seq |> List.of_seq in
       let glob_list = extract_globals file_name in
       (match glob_list with
        | Errors.OK l -> (List.iter
                           (fun symbol ->
                              sym_mapping := StrMap.add symbol module_name !sym_mapping;) (fst l)
                          ;
                          List.iter (fun (sym, dfn) -> (
                              match StrMap.find sym !composite_mapping with
                              (* first occurence *)
                              | None ->
                                (
                                  composite_mapping := StrMap.add sym (Some((module_name, dfn))) !composite_mapping;
                                )
                              (* set to none explicitly, do nothing *)
                              | Some (None) -> printf "UUID explicitly setting to NONE\n"; ()
                              | Some (Some (f, dfn_old)) -> (
                                  (* let (sou, mems, attrs) = match dfn with | Ctypes.Composite(_,a,b,c) -> (a, b, c) in *)
                                  (* let (sou_o, mems_o, attrs_o) = match dfn_old with | Ctypes.Composite(_,a,b,c) -> (a, b, c) in *)
                                  if not (comp_eq dfn dfn_old) then
                                    (* printf "sou is struct: %b, sou_o is struct %b" (sou == Ctypes.Struct) (sou_o == Ctypes.Union); *)
                                    (* printf "UUID inequal for %s with %b %b %b, replacing!\n" sym (sou = sou_o) (mems = mems_o) (attrs = attrs_o) ; *)
                                    composite_mapping := (StrMap.add sym None !composite_mapping);
                              )
                          )) (snd l))
        | Errors.Error _ -> printf "ERROR making mapping!"; ())

    ) !list_c_files

let tool_name = "CompCert AST generator"

(* Specific options *)

type export_mode = Mode_Csyntax | Mode_Clight | Mode_Rustlight
let option_mode = ref Mode_Rustlight
let option_normalize = ref false

(* Export the CompCert Csyntax AST *)

let export_csyntax sourcename csyntax ofile =
  let oc = open_out ofile in
  ExportCsyntax.print_program (Format.formatter_of_out_channel oc)
                              csyntax sourcename;
  close_out oc

(* Transform the CompCert Csyntax AST into Clight and export it *)

let export_clight sourcename csyntax ofile =
  let loc = file_loc sourcename in
  let clight =
    match SimplExpr.transl_program csyntax with
    | Errors.OK p ->
        begin match SimplLocals.transf_program p with
        | Errors.OK p' ->
            if !option_normalize
            then Clightnorm.norm_program p'
            else p'
        | Errors.Error msg ->
          fatal_error loc "%a" print_error  msg
        end
    | Errors.Error msg ->
      fatal_error loc "%a" print_error msg in
  (* Dump Clight in C syntax if requested *)
  PrintClight.print_if_2 clight;

  let oc = open_out ofile in
  ExportClight.print_program (Format.formatter_of_out_channel oc)
                             clight sourcename !option_normalize;
  close_out oc

(* let export_rustlight sourcename csyntax ofile = *)
(*   let loc = file_loc sourcename in *)

(* From C source to exported AST *)

let compile_c_file sourcename ifile ofile =
  let set_dest dst opt ext =
    dst := if !opt then Some (output_filename sourcename ~suffix:ext)
      else None in
  set_dest Cprint.destination option_dparse ".parsed.c";
  set_dest PrintCsyntax.destination option_dcmedium ".compcert.c";
  set_dest PrintClight.destination option_dclight ".light.c";
  set_dest PrintRustLight.destination option_drustlight ".light.rs";
  let cs = parse_c_file sourcename ifile in
  let module_name =
    String.sub sourcename 0 ((String.length sourcename) - 2)
    |> String.to_seq |> List.of_seq
  in

  match !option_mode with
  | Mode_Csyntax -> export_csyntax sourcename cs ofile
  | Mode_Clight  -> export_clight sourcename cs ofile
  | Mode_Rustlight -> (
      match
        (Compiler.print_r_program !sym_mapping !composite_mapping
               module_name cs) with
      | Errors.OK rprog -> (
          let oc = open_out ofile in
          ExportRustLight.print_program
            (Format.formatter_of_out_channel oc) rprog ifile
            !sym_mapping
            !composite_mapping
            module_name
        )
      | Errors.Error msg -> printf "error! %s" (C2C.string_of_errmsg msg)
      ;
  )

let output_filename sourcename  =
  let prefixname = Filename.remove_extension sourcename in
  output_filename_default (prefixname ^ ".v")

(* Processing of a .c file *)

let process_c_file sourcename =
  ensure_inputfile_exists sourcename;
  let ofile = output_filename sourcename in
  if !option_E then begin
    preprocess sourcename "-"
  end else begin
    let preproname = if !option_dprepro then
        Driveraux.output_filename sourcename ~suffix:".i"
      else
        Driveraux.tmp_file ".i" in
    preprocess sourcename preproname;
    compile_c_file sourcename preproname ofile
  end

(* Processing of a .i file *)

let process_i_file sourcename =
  ensure_inputfile_exists sourcename;
  let ofile = output_filename sourcename in
  compile_c_file sourcename sourcename ofile

let usage_string =
  version_string tool_name ^
{|Usage: clightgen <mode> [options] <source files>
Recognized source files:
  .c             C source file
  .i or .p       C source file that should not be preprocessed
Processing options:
  -clight        Produce Clight AST  [default]
  -csyntax       Produce Csyntax AST
  -normalize     Normalize the generated Clight code w.r.t. loads in expressions
  -canonical-idents  Use canonical numbers to represent identifiers  (default)
  -short-idents  Use small, non-canonical numbers to represent identifiers
  -E             Preprocess only, send result to standard output
  -o <file>      Generate output in <file>
|} ^
prepro_help ^
language_support_help ^
{|Tracing options:
  -dprepro       Save C file after preprocessing in <file>.i
  -dparse        Save C file after parsing and elaboration in <file>.parsed.c
  -dc            Save generated Compcert C in <file>.compcert.c
  -dclight       Save generated Clight in <file>.light.c
  -dall          Save all generated intermediate files in <file>.<ext>
|} ^
  general_help ^
  warning_help


let print_usage_and_exit () =
  printf "%s" usage_string; exit 0

let set_all opts () = List.iter (fun r -> r := true) opts
let unset_all opts () = List.iter (fun r -> r := false) opts

let actions : ((string -> unit) * string) list ref = ref []
let push_action fn arg =
  actions := (fn, arg) :: !actions

let perform_actions () =
  let rec perform = function
    | [] -> ()
    | (fn,arg) :: rem -> fn arg; perform rem
  in perform (List.rev !actions)

let num_input_files = ref 0

let cmdline_actions =
  [
(* Getting help *)
  Exact "-help", Unit print_usage_and_exit;
  Exact "--help", Unit print_usage_and_exit;]
  (* Getting version info *)
 @ version_options tool_name @
(* Processing options *)
 [
  Exact "-csyntax", Unit (fun () -> option_mode := Mode_Csyntax);
  Exact "-clight", Unit (fun () -> option_mode := Mode_Clight);
  Exact "-E", Set option_E;
  Exact "-normalize", Set option_normalize;
  Exact "-canonical-idents", Set Camlcoq.use_canonical_atoms;
  Exact "-short-idents", Unset Camlcoq.use_canonical_atoms;
  Exact "-o", String(fun s -> option_o := Some s);
  Prefix "-o", Self (fun s -> let s = String.sub s 2 ((String.length s) - 2) in
                              option_o := Some s);]
(* Preprocessing options *)
  @ prepro_actions @
(* Tracing options *)
  [ Exact "-dprepro", Set option_dprepro;
   Exact "-dparse", Set option_dparse;
   Exact "-dc", Set option_dcmedium;
   Exact "-dclight", Set option_dclight;
   Exact "-drustlight", Set option_drustlight;
   Exact "-dall", Self (fun _ ->
       option_dprepro := true;
       option_dparse := true;
       option_dcmedium := true;
       option_dclight := true;);
 ]
  @ general_options
(* Diagnostic options *)
  @ warning_options
  @ language_support_options @
(* Catch options that are not handled *)
  [Prefix "-", Self (fun s ->
     fatal_error no_loc "Unknown option `%s'" s);
(* File arguments *)
  Suffix ".c", Self (fun s ->
      incr num_input_files; push_action process_c_file s);
  Suffix ".i", Self (fun s ->
      incr num_input_files; push_action process_i_file s);
  Suffix ".p", Self (fun s ->
      incr num_input_files; push_action process_i_file s);
  ]

let _ =
try
  Gc.set { (Gc.get()) with
              Gc.minor_heap_size = 524288; (* 512k *)
              Gc.major_heap_increment = 4194304 (* 4M *)
         };
  Printexc.record_backtrace true;
  Camlcoq.use_canonical_atoms := true;
  Frontend.init ();
  generate_mapping ();
  let _ = Camlcoq.atom_of_string = (Hashtbl.create 17 : (string, Camlcoq.atom) Hashtbl.t) in
  let _ = Camlcoq.next_atom = ref BinNums.Coq_xH in
  parse_cmdline cmdline_actions;
  if !option_o <> None && !num_input_files >= 2 then
    fatal_error no_loc "Ambiguous '-o' option (multiple source files)";
  if !num_input_files = 0 then
    fatal_error no_loc "no input file";
  perform_actions ()
with
  | Sys_error msg
  | CmdError msg -> error no_loc "%s" msg; exit 2
  | Abort -> exit 2
  | e -> crash e
