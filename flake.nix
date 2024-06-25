{
  inputs = {
    nix-eda.url = github:efabless/nix-eda;
  };

  outputs = {self, nix-eda, ...}: {
    packages = nix-eda.forAllSystems { current = self; withInputs = [nix-eda]; } (util: with util; rec{
      fault = callPackage ./default.nix {};
      default = fault;
    });
  };
}
