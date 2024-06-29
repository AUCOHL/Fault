{
  lib,
  fetchFromGitHub,
  gccStdenv,
}:
gccStdenv.mkDerivation {
  pname = "atalanta";
  version = "2.0+";
  
  src = fetchFromGitHub {
    owner = "hsluoyz";
    repo = "atalanta";
    rev = "a8e07fe4af80c55b0d4ca77e382731b03ad731dc";
    sha256 = "sha256-e/E9qSPc0Pb+kLE8k169dXtAatCy8qUKHi5nNef5VUE=";
  };
  
  installPhase = ''
    mkdir -p $out/bin
    cp atalanta $out/bin
  '';
  
  meta = with lib; {
    description = "A modified ATPG (Automatic Test Pattern Generation) tool and fault simulator, orginally from VirginiaTech University.";
    homepage = "https://github.com/hsluoyz/Atalanta";
    license = licenses.unfree;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
