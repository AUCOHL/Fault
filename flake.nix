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
          verilog = pkgs.verilog.overrideAttrs( {
            version = "13.0";
            src = pkgs.fetchFromGitHub {
              owner = "steveicarus";
              repo = "iverilog";
              rev = "ea26587b5ef485f2ca82a3e4364e58ec3307240f";
              sha256 = "sha256-OIpNUn04A5ViDm8QH7xY2IKPMU3wg9sNZMzMUAq8Q4U=";
            };
            patches = [];
          });
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
          pyenv = python3.withPackages (ps: with ps; [pyverilog pyyaml pytest nl2bench]);
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
          PYTHONPATH = "${pyenv}/${pyenv.sitePackages}";
          FAULT_IVL_BASE = "${verilog}/lib/ivl";
        });
      }
    );
  };
}
