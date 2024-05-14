{ lib, stdenv, pkgs, mkCoqDerivation, coq, fetchurl, version ? null }:

mkCoqDerivation {
  pname = "coqrel";
  owner = "CertiKOS";

  release."2023-03-29".rev    = "71699719ffd1cd8202e8ffeaf0faf890c765105a";
  release."2023-03-29".sha256 = "sha256-kIyd2HD5+jDDJoOJ8/wBW3y+i3QH+U/oTes2CYH6mWM=";

  inherit version;
  defaultVersion = with lib.versions; lib.switch coq.version [
    { case = isEq "8.12"; out = "2023-03-29"; }
  ] null;

  meta = with lib; {
    description = "Binary logical relations library for the Coq proof assistant";
    maintainers = with maintainers; [ siraben ];
    license = licenses.mit;
    platforms = platforms.unix;
  };

  enableParallelBuilding = true;
}

