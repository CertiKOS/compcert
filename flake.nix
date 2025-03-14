{
  description = "nix shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, utils, fenix }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # dont' need this but leaving it here just in case I want to
          # do something similar
          # overlays = [ (import ./overlay.nix) ];
        };

        fenixStable = with fenix.packages.${system};
          combine [
            (latest.withComponents [
              "miri"
              "cargo"
              "clippy"
              "rust-src"
              "rustc"
              "rustfmt"
              "llvm-tools-preview"
            ])
          ];
      in {
        # packages.compcerto = pkgs.coqPackages_8_12.compcerto;
        packages.devshell = self.devShell.${system};
        devShell = pkgs.mkShell.override { } {
          OCAMLGRAPHPATH = "${pkgs.coqPackages_8_19.coq.ocamlPackages.ocamlgraph}/lib/ocaml/4.14.2/site-lib/ocamlgraph";
          ARCH = if "${system}" == "aarch64-darwin" then "aarch64-macos" else "${system}";
          RUST_SRC_PATH = "${fenixStable}/lib/rustlib/src/rust/library";
          RUST_LIB_SRC = "${fenixStable}/lib/rustlib/src/rust/library";
          RUSTFLAGS = "-Cpanic=abort -Zpanic-abort-tests";
          shellHook = ''
            export PATH="$PATH:$PWD"
            export "RUNTIME=$PWD/runtime"
          '';
          buildInputs = with pkgs; [
            pkgs.darwin.apple_sdk.frameworks.CoreServices
            pkgs.darwin.apple_sdk.frameworks.System
            pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
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

            coqPackages_8_19.coq.ocamlPackages.core
            coqPackages_8_19.coq.ocamlPackages.dune_2
            coqPackages_8_19.coq.ocamlPackages.findlib
            # coqPackages_8_19.coq.ocamlPackages.utop
            coqPackages_8_19.coq.ocamlPackages.cryptokit
            coqPackages_8_19.coq.ocamlPackages.ocamlbuild
            coqPackages_8_19.coq.ocamlPackages.cppo
            coqPackages_8_19.coq.ocamlPackages.extlib
            coqPackages_8_19.coq.ocamlPackages.yojson
            coqPackages_8_19.coq.ocamlPackages.zarith

            coqPackages_8_19.coq.ocamlPackages.ocaml
            coqPackages_8_19.coq.ocamlPackages.menhir
            coqPackages_8_19.coq.ocamlPackages.menhirLib
            coqPackages_8_19.coq.ocamlPackages.merlin
            # coqPackages_8_19.coq.ocamlPackages.utop
            coqPackages_8_19.coq.ocamlPackages.ocp-indent
            coqPackages_8_19.coq.ocamlPackages.ocaml-lsp
            coqPackages_8_19.coq.ocamlPackages.dot-merlin-reader
            coqPackages_8_19.coq.ocamlPackages.ocamlformat
            coqPackages_8_19.coq.ocamlPackages.ocamlgraph
            coqPackages_8_19.coq-lsp

            # ocaml-ng.ocamlPackages_4_10.ocaml-lsp
            # coqPackages_8_19.coq.ocamlPackages.ocamlformat

            # ocamlPackages_4_12.menhir
            # coqPackages_8_19.coqhammer
            # coqPackages_8_12.smtcoq
            coq_8_19
            pkg-config
            just
            typst
            # cvc4
            libiconv
            # coqPackages.vscoq-language-server
         ];
        };
      });
}
