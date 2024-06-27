{
  pkgs? import <nixpkgs> {}
}:
with pkgs; stdenvNoCC.mkDerivation {
  # Use the host's Clang and Swift, they're hopelessly broken in Nix
  name = "shell";
  buildInputs = [
    yosys
    verilog
    (python3.withPackages(ps: with ps; [pyverilog]))
    gtkwave
  ];
  
  PYTHON_LIBRARY="${python3}/lib/lib${python3.libPrefix}${stdenvNoCC.hostPlatform.extensions.sharedLibrary}";
  FAULT_IVL_BASE="${verilog}/lib/ivl";
}
