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
  };
}
