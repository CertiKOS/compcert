final: prev:

let
  callPackage = prev.callPackage;
in

{
  coqPackages_8_12 = prev.coqPackages_8_12 // rec {
    coqrel = final.coqPackages_8_12.callPackage ./coqrel.nix { };
    compcerto = final.coqPackages_8_12.callPackage ./compcerto.nix { inherit coqrel; ocamlPackages = final.ocaml-ng.ocamlPackages_4_14;};
  };
}

