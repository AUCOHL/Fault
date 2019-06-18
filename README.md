# Fault
Fault is an automatic test pattern generator for netlists.

# Dependencies
* Swift 5.0+
* Python 3.7+
* Yosys 0.8+
* Icarus Verilog 10.2+

## Installing
### macOS
Install the latest Xcode from the Mac App Store.

Use [Homebrew](https://brew.sh).

`brew install python yosys icarus-verilog`

### Debian-based Linuces (e.g. Ubuntu)
Using apt:

`sudo apt install git clang python yosys iverilog`

Then install the Swift programming language: instructions are on [swift.org](https://swift.org/download/#using-downloads).

# Usage
## First time
Type `git submodule update --init --recursive` in the terminal to initialize submodules.

## Running
* run `synth.swift <liberty-file> <rtl> <output>` on a valid Verilog file. This will generate a netlist using Yosys.
* run `swift run Fault -n <cell-model> <netlist>`.

Generated test vectors are printed to stdout by default, but you can use `-o <file>` (or simply redirect the output).

# License
After this repository becomes public, the GNU General Public License v3 (or later, at your option). See 'License'.