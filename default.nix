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
  quaigh,
  ncurses,
  makeBinaryWrapper,
}:
let
  generated = swiftpm2nix.helpers ./nix;
  pyenv = (python3.withPackages(ps: with ps; [pyverilog]));
  stdenv = swiftPackages.stdenv;
in
stdenv.mkDerivation (finalAttrs: {
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
    quaigh
  ];
  
  buildInputs = with swiftPackages; [
    Foundation
    XCTest
  ] ++ lib.lists.optional (!stdenv.isDarwin) [Dispatch];
  
  configurePhase = generated.configure;

  installPhase = ''
    binPath="$(swiftpmBinPath)"
    mkdir -p $out/bin
    cp $binPath/fault $out/bin/fault
  '';
  
  # This doesn't work on Linux otherwise and I don't know why.
  preBuild = if stdenv.isDarwin then "" else ''
    export LD_LIBRARY_PATH=${swiftPackages.Dispatch}/lib:$LD_LIBRARY_PATH
  '';
  
  doCheck = !swiftPackages.stdenv.isDarwin;
  
  preCheck = ''
    export PYTHONPATH=${pyenv}/${pyenv.sitePackages}
    export PATH=${verilog}/bin:$PATH
    export PATH=${yosys}/bin:$PATH
    export PYTHON_LIBRARY=${pyenv}/lib/lib${pyenv.libPrefix}${swiftPackages.stdenv.hostPlatform.extensions.sharedLibrary}
    export FAULT_IVL_BASE=${verilog}/lib/ivl
  '';
  
  checkPhase = ''
    ${finalAttrs.preCheck}
    echo $PATH
    swift test
  '';
  
  fixupPhase = ''
    wrapProgram $out/bin/fault\
      --prefix PYTHONPATH : ${pyenv}/${pyenv.sitePackages}\
      --prefix PATH : ${verilog}/bin\
      --prefix PATH : ${yosys}/bin\
      --set PYTHON_LIBRARY ${pyenv}/lib/lib${pyenv.libPrefix}${swiftPackages.stdenv.hostPlatform.extensions.sharedLibrary}\
      --set FAULT_IVL_BASE ${verilog}/lib/ivl
  '';
  
  meta = with lib; {
    description = "Open-source EDA's missing DFT toolchain";
    homepage = "https://github.com/AUCOHL/Fault";
    license = licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
  };
  
  shellHook = finalAttrs.preCheck + finalAttrs.preBuild;
})
