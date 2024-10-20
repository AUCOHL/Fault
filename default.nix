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
}: let
  generated = swiftpm2nix.helpers ./nix;
  pyenv = python3.withPackages (ps: with ps; [nl2bench pyverilog]);
  stdenv = swiftPackages.stdenv;
in
  stdenv.mkDerivation (finalAttrs: {
    name = "fault";

    src = nix-gitignore.gitignoreSourcePure ./.gitignore ./.;

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
    nativeBuildInputs = [swift swiftpm makeBinaryWrapper];

    buildInputs = with swiftPackages;
      [
        Foundation
        XCTest
      ]
      ++ lib.lists.optional (!stdenv.isDarwin) [Dispatch];

    nativeCheckInputs = with python3.pkgs; [
      pytest
    ];

    configurePhase = generated.configure;

    # This doesn't work on Linux otherwise and I don't know why.
    preBuild =
      if stdenv.isDarwin
      then ""
      else ''
        export LD_LIBRARY_PATH=${swiftPackages.Dispatch}/lib:$LD_LIBRARY_PATH
      '';

    doCheck = true;

    faultEnv = ''
      export PATH=${pyenv}/bin:${quaigh}/bin:${yosys}/bin:${verilog}/bin:$PATH
      export PYTHONPATH=${pyenv}/${pyenv.sitePackages}
      export PYTHON_LIBRARY=${pyenv}/lib/lib${pyenv.libPrefix}${swiftPackages.stdenv.hostPlatform.extensions.sharedLibrary}
      export FAULT_IVL_BASE=${verilog}/lib/ivl
    '';

    checkPhase = ''
      runHook preCheck
      ${finalAttrs.faultEnv}
      PYTEST_FAULT_BIN="$(swiftpmBinPath)/fault" pytest
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      binPath="$(swiftpmBinPath)"
      mkdir -p $out/bin
      cp $binPath/fault $out/bin/fault
      ln -s ${python3.pkgs.nl2bench}/bin/nl2bench $out/bin/nl2bench
      runHook postInstall
    '';

    fixupPhase = ''
      runHook preFixup
      wrapProgram $out/bin/fault\
        --prefix PATH : ${pyenv}/bin\
        --prefix PATH : ${verilog}/bin\
        --prefix PATH : ${quaigh}/bin\
        --prefix PATH : ${yosys}/bin\
        --prefix PYTHONPATH : ${pyenv}/${pyenv.sitePackages}\
        --set PYTHON_LIBRARY ${pyenv}/lib/lib${pyenv.libPrefix}${swiftPackages.stdenv.hostPlatform.extensions.sharedLibrary}\
        --set FAULT_IVL_BASE ${verilog}/lib/ivl
      runHook postFixup
    '';

    meta = with lib; {
      description = "Open-source EDA's missing DFT toolchain";
      homepage = "https://github.com/AUCOHL/Fault";
      license = licenses.asl20;
      platforms = platforms.linux ++ platforms.darwin;
    };

    shellHook = finalAttrs.faultEnv + finalAttrs.preBuild;
  })
