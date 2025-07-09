open Js_of_ocaml
open Linking

let log_fn s = Js_of_ocaml.Console.console##log (Js.string s)

(* open Lwt.Infix *)
module Events = Js_of_ocaml_lwt.Lwt_js_events
module Html = Dom_html

let csyntax_mapping :
    (string, Csyntax.coq_function Ctypes.program) Hashtbl.t ref =
  ref (Hashtbl.create 5)
(**)
let run_translator mystr =
  Debug.init_compile_unit "sample";
  Sections.initialize ();
  CPragmas.reset ();

  let ast =
    Parse.preprocessed_file_from_string ~unblock:true ~switch_norm:`Full
      ~struct_passing:true ~packed_structs:true "sample" mystr
  in
  let csyntax = C2C.convertProgram ast in
  Hashtbl.replace !csyntax_mapping "my_mod" csyntax;
  let glob_list = Compiler.get_exports csyntax in
  (match glob_list with
      | Errors.OK (lvars, ltyps) ->
          List.fold_left
            (fun () (id, defn) ->
              Linking.add_globdef !PrintRustLight.linker ~name:id ~mod_name:"my_mod"
                ~defn)
            () lvars;
          List.fold_left
            (fun () (id, cd) ->
              Linking.add_ty_defn !PrintRustLight.linker ~mod_name:"my_mod" ~cd)
            () ltyps
      | Errors.Error _ ->
          log_fn "ERROR making mapping!");

  Linking.fill_out_rep_types !PrintRustLight.linker;

  match Compiler.r_program_of_cfg csyntax with
  | Errors.OK s -> s |> List.to_seq |> String.of_seq
  | Errors.Error msg -> "error"

let add_handler id =
  let btn = Html.getElementById id in
  btn##.onclick :=
    Html.handler (fun _ ->
        let input_ele = Html.getElementById "cCode" in
        let input_textarea = Js.Unsafe.coerce input_ele in
        let input_value = Js.to_string input_textarea##.value in
        let output_ele = Html.getElementById "rustOutput" in

        let res = run_translator input_value in

        output_ele##.textContent := Js.Opt.return (Js.string res);
        log_fn "Clicked7878!\n";
        log_fn res;
        Js._false)

let () =
  print_endline "hello 200 from wasm 2";

  Gc.set
    {
      (Gc.get ()) with
      Gc.minor_heap_size = 524288;
      (* 512k *)
      Gc.major_heap_increment = 4194304 (* 4M *);
    };
  Printexc.record_backtrace true;
  Frontend.init ();
  add_handler "my_button"
