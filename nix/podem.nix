{
  lib,
  gccStdenv,
  fetchFromGitHub,
}:
gccStdenv.mkDerivation {
  name = "nctu-ee-podem";
  version = "0.1.0";
  
  src = fetchFromGitHub {
    owner = "donn";
    repo = "VLSI-Testing";
    rev = "ff82db776521b294d79d54acc00b7b6eaaa5846d";
    sha256 = "sha256-Nj8hQb9XlRjIIrfht8VNEfORmwtb+WWrP6UVlWgo81A=";
  };
  
  postPatch = ''
    sed -i 's/^LIBS.*/LIBS = /' podem/Makefile
  '';
  
  buildPhase = ''
    make -C podem
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    cp podem/atpg $out/bin/atpg-podem
  '';
  
  meta = with lib; {
    description = "A C++ implementation of PODEM used in the testing course of the NCTU EE program";
    homepage = "https://github.com/cylinbao/VLSI-Testing";
    license = licenses.unfree;
    mainProgram = "atpg-podem";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
