{
  description = "nix shell";

  inputs = {
    nixpkgs.url = "github:DieracDelta/nixpkgs/jr/coqfmt";
    utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay-old.url = "github:oxalica/rust-overlay/f0bcb23e31033ab31639e6a1d85c44ce6ccaa335";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-21.05";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      utils,
      fenix,
      rust-overlay,
      rust-overlay-old,
      nixpkgs-old,
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs_unapplied =
          np: ra:
          import np {
            inherit system;
            # dont' need this but leaving it here just in case I want to
            # do something similar
            overlays = [ (import ra) ];
          };
        pkgs = pkgs_unapplied nixpkgs rust-overlay;
        pkgs_old = pkgs_unapplied nixpkgs-old rust-overlay-old;
        rust_tc_2024 = pkgs.rust-bin.selectLatestNightlyWith (
          toolchain:
          toolchain.default.override {
            extensions = [
              "rust-src"
              "rustc-dev"
              "llvm-tools-preview"
              "miri"
            ];
          }
        );
        rust_tc_2021 = pkgs_old.rust-bin.nightly."2022-08-08".default.override {
          extensions = [
            "rust-src"
            "rustc-dev"
            "llvm-tools-preview"
          ];
        };
        baseBuildInputs = with pkgs; [
          llvmPackages_latest.clang-tools
          llvmPackages_latest.clang
          llvmPackages_latest.openmp

          pkgs.darwin.apple_sdk.frameworks.CoreServices
          pkgs.darwin.apple_sdk.frameworks.System
          pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
          python3
          fenix.packages.${system}.rust-analyzer
          # rustc deps
          ninja
          llvmPackages_latest.llvm
          llvmPackages_latest.libclang
          rustPlatform.bindgenHook
          zlib
          openssl

          coqPackages_8_20.coq.ocamlPackages.core
          coqPackages_8_20.coq.ocamlPackages.dune_2
          coqPackages_8_20.coq.ocamlPackages.findlib
          # coqPackages_8_20.coq.ocamlPackages.utop
          coqPackages_8_20.coq.ocamlPackages.cryptokit
          coqPackages_8_20.coq.ocamlPackages.ocamlbuild
          coqPackages_8_20.coq.ocamlPackages.cppo
          coqPackages_8_20.coq.ocamlPackages.extlib
          coqPackages_8_20.coq.ocamlPackages.yojson
          coqPackages_8_20.coq.ocamlPackages.zarith

          coqPackages_8_20.coq.ocamlPackages.ocaml
          coqPackages_8_20.coq.ocamlPackages.menhir
          coqPackages_8_20.coq.ocamlPackages.menhirLib
          coqPackages_8_20.coq.ocamlPackages.merlin
          # coqPackages_8_20.coq.ocamlPackages.utop
          coqPackages_8_20.coq.ocamlPackages.ocp-indent
          coqPackages_8_20.coq.ocamlPackages.ocaml-lsp
          coqPackages_8_20.coq.ocamlPackages.dot-merlin-reader
          coqPackages_8_20.coq.ocamlPackages.ocamlformat
          coqPackages_8_20.coq.ocamlPackages.ocamlgraph
          coqPackages_8_20.coq-lsp
          coqPackages_8_20.coqfmt

          # ocaml-ng.ocamlPackages_4_10.ocaml-lsp
          # coqPackages_8_20.coq.ocamlPackages.ocamlformat

          # ocamlPackages_4_12.menhir
          # coqPackages_8_20.coqhammer
          # coqPackages_8_12.smtcoq
          coq_8_20
          pkg-config
          autoconf
          autoreconfHook
          libnl
          libcap
          cargo-expand

          just
          typst
          # cvc4
          libiconv

          # for robotsmeetkittens
          ncurses
          ncurses.dev
          # for tmux
          libevent
          libevent.dev
          # coqPackages.vscoq-language-server
        ];

      in
      {
        # packages.compcerto = pkgs.coqPackages_8_12.compcerto;
        packages.devshell = self.devShells.${system}.E2024;
        devShells.E2024 = pkgs.mkShell {
          OCAMLGRAPHPATH = "${pkgs.coqPackages_8_19.coq.ocamlPackages.ocamlgraph}/lib/ocaml/4.14.2/site-lib/ocamlgraph";
          ARCH = if "${system}" == "aarch64-darwin" then "aarch64-macos" else "${system}";
          RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
          RUSTFLAGS = "-Awarnings -Cpanic=abort -Zpanic-abort-tests -Astatic_mut_refs";
          shellHook = ''
            export PATH="$PATH:$PWD"
            export "RUNTIME=$PWD/runtime"
          '';
          buildInputs = baseBuildInputs ++ [ rust_tc_2024 ];
        };

        devShells.E2021 = pkgs.mkShell {
          OCAMLGRAPHPATH = "${pkgs.coqPackages_8_19.coq.ocamlPackages.ocamlgraph}/lib/ocaml/4.14.2/site-lib/ocamlgraph";
          ARCH = if "${system}" == "aarch64-darwin" then "aarch64-macos" else "${system}";
          RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
          RUSTFLAGS = "-Awarnings -Cpanic=abort -Zpanic-abort-tests";
          shellHook = ''
            export PATH="$PATH:$PWD"
            export "RUNTIME=$PWD/runtime"
          '';
          buildInputs = baseBuildInputs ++ [ rust_tc_2021 ];
        };
      }
    );
}
