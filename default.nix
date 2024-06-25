{
  lib,
  swift,
  swiftpm,
  swiftpm2nix,
  swiftPackages,
  nix-gitignore,
  python3,
  yosys,
  verilog,
  ncurses,
  makeBinaryWrapper,
}:
let
  generated = swiftpm2nix.helpers ./nix;
  pyenv = (python3.withPackages(ps: with ps; [pyverilog]));
in
swiftPackages.stdenv.mkDerivation rec {
	name = "fault";
	
	src = nix-gitignore.gitignoreSourcePure ./.gitignore ./.;
  
  nativeBuildInputs = [ swift swiftpm makeBinaryWrapper ];
	swiftpmFlags = [
    "--verbose"
  ];
  # ++ lib.lists.optional swiftPackages.stdenv.isDarwin [
  #   "-Xcc"
  #   "-mmacosx-version-min=11"
  #   "-Xcc"
  #   "-target"
  #   "-Xcc"
  #   "x86_64-apple-macosx11"
  #   "-Xswiftc"
  #   "-target"
  #   "-Xswiftc"
  #   "x86_64-apple-macosx11"
  # ];
  
  propagatedBuildInputs = [
    pyenv
    yosys
    verilog
  ];
  
  buildInputs = [
    swiftPackages.Foundation
  ];
  
  configurePhase = generated.configure;

  installPhase = ''
    binPath="$(swiftpmBinPath)"
    mkdir -p $out/bin
    cp $binPath/Fault $out/bin/
  '';
  
  fixupPhase = ''
    wrapProgram $out/bin/fault\
      --prefix PYTHONPATH : ${pyenv}/${pyenv.sitePackages}\
      --prefix PATH : ${verilog}/bin\
      --prefix PATH : ${yosys}/bin\
      --set PYTHON_LIBRARY ${pyenv}/lib/lib${pyenv.libPrefix}${swiftPackages.stdenv.hostPlatform.extensions.sharedLibrary}\
      --set FAULT_IVL_BASE ${verilog}/lib/ivl
  '';
}
