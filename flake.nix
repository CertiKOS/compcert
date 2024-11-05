{
  description = "nix shell";

  inputs = {
    nixpkgs.url = "github:DieracDelta/nixpkgs/jr/lower_coq";
    utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, utils, fenix}:
    utils.lib.eachDefaultSystem (system:
    let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import ./overlay.nix )];
        };

        fenixStable = with fenix.packages.${system}; combine [
            (latest.withComponents [ "cargo" "clippy" "rust-src" "rustc" "rustfmt" "llvm-tools-preview" ])
          ];
        in {
          packages.compcerto = pkgs.coqPackages_8_12.compcerto;
          packages.devshell = self.devShell.${system};
          devShell = pkgs.mkShell.override {} {
          RUST_SRC_PATH = "${fenixStable}/lib/rustlib/src/rust/library";
          RUST_LIB_SRC = "${fenixStable}/lib/rustlib/src/rust/library";
            # buildInputs = [pkgs.nixStable];
             buildInputs =
               with pkgs; [
                 python3
                 fenixStable
                 nixStable
                 fenix.packages.${system}.rust-analyzer
                 # rustc deps
                 ninja
                 llvmPackages_latest.llvm
                 llvmPackages_latest.libclang
                 zlib
                 openssl


                 coqPackages_8_12.coq.ocamlPackages.core
                 coqPackages_8_12.coq.ocamlPackages.dune_2
                 coqPackages_8_12.coq.ocamlPackages.findlib
                 # coqPackages_8_12.coq.ocamlPackages.utop
                 coqPackages_8_12.coq.ocamlPackages.cryptokit
                 coqPackages_8_12.coq.ocamlPackages.ocamlbuild
                 coqPackages_8_12.coq.ocamlPackages.cppo
                 coqPackages_8_12.coq.ocamlPackages.extlib
                 coqPackages_8_12.coq.ocamlPackages.yojson
                 coqPackages_8_12.coq.ocamlPackages.zarith

                 coqPackages_8_12.coq.ocamlPackages.ocaml
                 coqPackages_8_12.coq.ocamlPackages.menhir
                 coqPackages_8_12.coq.ocamlPackages.menhirLib
                 coqPackages_8_12.coq.ocamlPackages.merlin
                 # coqPackages_8_12.coq.ocamlPackages.utop
                 coqPackages_8_12.coq.ocamlPackages.ocp-indent
                 ocaml-ng.ocamlPackages_4_10.ocaml-lsp
                 # coqPackages_8_12.coq.ocamlPackages.ocamlformat

                 # ocamlPackages_4_12.menhir
                 coqPackages_8_12.coqhammer
                 # coqPackages_8_12.smtcoq
                 coq_8_12
                 pkg-config
                 just
                 typst
                 cvc4
                 libiconv
               ];
          };
    });
}

# { src ? import ./nix/sources.nix
# , pkgs ? import src.nixpkgs {} }:
# with pkgs;
#
# mkShell {
#   packages = [
#     coq_8_12
#     coqPackages_8_12.coqhammer
#     vampire
#     eprover
#     cvc4
#     (z3-tptp.overrideAttrs (oA: {
#       installPhase = oA.installPhase + ''
#     ln -s "z3_tptp5" "$out/bin/z3_tptp"
#   '';
#     }))
#   ];
# }

