# 🧪 Fault
Fault is an automatic test pattern generator for netlists that includes scan chain stitching.

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

Then simply invoke `swift install.swift`. This will install it to `~/bin` by default, type `swift install.swift help me` for more options.

## Running
### Subprograms
#### synth
Synth is a synthesis script included with Fault that generates both a netlist and a cut-away version.

To run it, `swift run Fault synth --top <your-top-module> --liberty <your-liberty-file> <your-file>`. When using the installed version, you can simply invoke `fault synth`, and you can optionally omit` --liberty` where osu035 will be used.

For more options, write `fault synth --help`.

#### main
`swift run Fault --cellModel <your-cell-models> <your-file>`, `--cellModel` behaving similar to `--liberty` in synth when installed.

A set of assumptions are made about the input file:
* It is a netlist
* It is flattened (there is only one module with no submodules)
* The flipflops have been cut away and replaced with outputs and inputs.

Generated test vectors are printed to stdout by default, but you can use `-o <file>` (or simply redirect the output).

For more options, write `fault --help`.

### chain
`swift run Fault chain --liberty <your-liberty-file> <your-file>`, `--liberty` behaving identical synth.

Chain is another synthesis script that links registers together for scan insertion. It takes all the assumptions made in the main program but the last, and one more:
* All instantiated D flipflops start with "DFF".

A note about the liberty file in use in this step is that we recommend a modified liberty file that keeps only a buffer, an and, and a multiplexer (and an inverter if necessary), as abc tends to overthink multiplexers.

Chain will output information about the scan chain embedded in the output netlist as `/* FAULT METADATA: '<json>' */` after the boilerplate. This metadata includes things like port names, the DFF count and ***\[\[\[STILL NOT DONE\]\]\]*** the order of the registers in the scan chain.

For more options, write `fault chain --help`.

There will be an option or fourth program to verify the scan chain integrity.

# License
After this repository becomes public, the GNU General Public License v3 (or later, at your option). See 'License'.

# References
- Z. Navabi, Digital System Test and Testable Design : Using Hdl Models and Architectures. 2010;2011;. DOI: 10.1007/978-1-4419-7548-5.
- Shinya Takamaeda-Yamazaki: Pyverilog: A Python-based Hardware Design Processing Toolkit for Verilog HDL, 11th International Symposium on Applied Reconfigurable Computing (ARC 2015) (Poster), Lecture Notes in Computer Science, Vol.9040/2015, pp.451-460, April 2015.
[Paper](http://link.springer.com/chapter/10.1007/978-3-319-16214-0_42)