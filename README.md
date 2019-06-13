# Fault
# Dependencies
* Swift 5.0+
    * Xcode 10.2+ on macOS
* Python 3.7+
* Yosys 0.8+
* Icarus Verilog 10.2+
* Pyverilog
    * Simply type `git submodule update --init --recursive` in the terminal: no need to install

# Usage
* run `synth.swift <liberty-file> <rtl> <output>` on a valid Verilog file. This will generate a netlist using Yosys.
* run `swift run Fault -n <cell-model> <netlist>`.

Generated test vectors are printed to stdout.

# License
TBD.