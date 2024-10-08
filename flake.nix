{
  inputs = {
    nix-eda.url = github:efabless/nix-eda;
    nl2bench = {
      url = github:donn/nl2bench/pyosys;
      inputs.nix-eda.follows = "nix-eda";
    };
    quaigh = {
      url = github:coloquinte/quaigh;
      inputs.nixpkgs.follows = "nix-eda/nixpkgs";
    };
  };

  outputs = {self, nix-eda, quaigh, nl2bench, ...}: {
    packages = nix-eda.forAllSystems { current = self; withInputs = [nix-eda quaigh nl2bench]; } (util: with util; rec{
      atalanta = callPackage ./nix/atalanta.nix {};
      podem = callPackage ./nix/podem.nix {};
      fault = callPackage ./default.nix {};
      default = fault;
    });
    
    devShells = nix-eda.forAllSystems { withInputs = [nix-eda quaigh nl2bench self]; } (util: with util; rec {
      mac-testing = pkgs.stdenvNoCC.mkDerivation (with pkgs; let
        pyenv = (python3.withPackages(ps: with ps; [pyverilog pyyaml pytest pkgs.nl2bench]));
      in {
        # Use the host's Clang and Swift
        name = "shell";
        buildInputs = [
          yosys
          verilog
          pkgs.quaigh
          pyenv
          gtkwave
        ];
        
        PYTHON_LIBRARY="${pyenv}/lib/lib${python3.libPrefix}${stdenvNoCC.hostPlatform.extensions.sharedLibrary}";
        PYTHONPATH="${pyenv}/${pyenv.sitePackages}";
        FAULT_IVL_BASE="${verilog}/lib/ivl";
      });
    });
  };
}
