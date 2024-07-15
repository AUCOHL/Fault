{
  inputs = {
    nix-eda.url = github:efabless/nix-eda;
    quaigh = {
      url = github:donn/quaigh;
      inputs.nixpkgs.follows = "nix-eda/nixpkgs";
    };
  };

  outputs = {self, nix-eda, quaigh, ...}: {
    packages = nix-eda.forAllSystems { current = self; withInputs = [nix-eda quaigh]; } (util: with util; rec{
      atalanta = callPackage ./nix/atalanta.nix {};
      fault = callPackage ./default.nix {};
      default = fault;
    });
    
    devShells = nix-eda.forAllSystems { withInputs = [nix-eda quaigh self]; } (util: with util; rec {
      mac-testing = pkgs.stdenvNoCC.mkDerivation (with pkgs; {
        # Use the host's Clang and Swift
        name = "shell";
        buildInputs = [
          yosys
          verilog
          pkgs.quaigh
          (python3.withPackages(ps: with ps; [pyverilog pyyaml pytest]))
          gtkwave
        ];
        
        PYTHON_LIBRARY="${python3}/lib/lib${python3.libPrefix}${stdenvNoCC.hostPlatform.extensions.sharedLibrary}";
        FAULT_IVL_BASE="${verilog}/lib/ivl";
      });
    });
  };
}
