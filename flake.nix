{
  inputs = {
    nix-eda.url = github:efabless/nix-eda;
    quaigh = {
      url = github:coloquinte/quaigh;
      inputs.nixpkgs.follows = "nix-eda/nixpkgs";
    };
    nl2bench = {
      url = github:donn/nl2bench;
      inputs.nix-eda.follows = "nix-eda";
      inputs.quaigh.follows = "quaigh";
    };
  };

  outputs = {
    self,
    nix-eda,
    quaigh,
    nl2bench,
    ...
  }: let
    nixpkgs = nix-eda.inputs.nixpkgs;
    lib = nixpkgs.lib;
  in {
    overlays = {
      default = lib.composeManyExtensions [
        (nix-eda.flakesToOverlay [quaigh])
        nl2bench.overlays.default
        (pkgs': pkgs: let
          callPackage = lib.callPackageWith pkgs';
        in {
          atalanta = callPackage ./nix/atalanta.nix {};
          podem = callPackage ./nix/podem.nix {};
          fault = callPackage ./default.nix {};
        })
      ];
    };

    legacyPackages = nix-eda.forAllSystems (
      system:
        import nixpkgs {
          inherit system;
          overlays = [nix-eda.overlays.default self.overlays.default];
        }
    );

    packages = nix-eda.forAllSystems (system: {
      inherit (self.legacyPackages.${system}) atalanta podem fault;
      default = self.packages.${system}.fault;
    });

    devShells = nix-eda.forAllSystems (
      system: let
        pkgs = self.legacyPackages."${system}";
        callPackage = lib.callPackageWith pkgs;
      in {
        mac-testing = pkgs.stdenvNoCC.mkDerivation (with pkgs; let
          pyenv = python3.withPackages (ps: [ps.pyverilog ps.pyyaml ps.pytest ps.nl2bench]);
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

          PYTHON_LIBRARY = "${pyenv}/lib/lib${python3.libPrefix}${stdenvNoCC.hostPlatform.extensions.sharedLibrary}";
          NIX_PYTHONPATH = "${pyenv}/${pyenv.sitePackages}";
          PYTHONPATH = "${pyenv}/${pyenv.sitePackages}";
          FAULT_IVL_BASE = "${verilog}/lib/ivl";
        });
      }
    );
  };
}
