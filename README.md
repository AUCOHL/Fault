# Fault
# Dependencies
* Swift 5.0+
    * Xcode 10.2+ on macOS
* Python 3.7+
* Yosys 0.8+
* Pyverilog
    * Simply type `git submodule update --init --recursive` in the terminal: no need to install

# Usage
* run `synth.swift <file>` on a valid Verilog file. This will generate a netlist using Yosys named `Netlist/<file>.netlist.v`.
* run `swift run Fault -n Tech/osu035/osu035_stdcells.v Netlist/<file>.netlist.v`.

The vectors being output are printed to stdout.

# License
TBD.