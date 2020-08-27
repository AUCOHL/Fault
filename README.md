# 🧪 Fault
Fault is a complete open source design for testing (DFT) Solution that includes automatic test pattern generation for netlists, scan chain stitching, synthesis scripts and a number of other convenience features.

# Quick Setup/Walkthrough
You may refer to the [wiki](https://github.com/Cloud-V/Fault/wiki) for quick setup instructions (and a small walkthrough!) if you're into that.

# Running
## Subcommands
### synth
Synth is a synthesis script included with Fault that generates both a netlist and a cut-away version.

To run it, `fault synth --top <your-top-module> --liberty <your-liberty-file> <your-file>`. You can optionally omit` --liberty` where osu035 will be used.

For more options, you can invoke `fault synth --help`.

### cut
`fault cut <your-netlist>`

This exposes the D-flipflops as ports for use with the main script.

For more options, you can invoke `fault cut --help`.

### main
`fault --cellModel <your-cell-models> <your-file>`, `--cellModel` behaving similar to `--liberty` in synth.

A set of assumptions are made about the input file:
* It is a netlist
* It is flattened (there is only one module with no submodules)
* The flipflops have been cut away and replaced with outputs and inputs.

Generated test vectors are printed to stdout by default, but you can use `-o <file>` (or simply redirect the output).

For more options, you can invoke `fault --help`.

### chain
`fault chain --liberty <your-liberty-file> --clock <clockName> --reset <resetName> <--activeLow> <your-file>`, `--liberty` behaving identical to Synth.

Chain is another synthesis script that links registers together for scan insertion. It takes all the assumptions made in the main program but the last, and one more:
* All instantiated D flipflops start with "DFF".

A note about the liberty file in use in this step is that we recommend a modified liberty file that keeps only a buffer, an and gate, and a multiplexer (and an inverter if necessary), as abc tends to overthink multiplexers.

Chain will output information about the scan chain embedded in the output netlist as `/* FAULT METADATA: '<json>' */` after the boilerplate. This metadata includes things like port names, the DFF count and the order of the registers in the scan chain.

You can have Chain automagically verify its generated scanchain-- see the help for more options, but the gist of it is `-v <your-cell-model>`.

For more options, you can invoke `fault chain --help`.

### asm
`fault asm <test vector json> <chained netlist>`, in any order, will assemble a .bin file for use with `$readmemb`.

For more options, you can invoke `fault asm --help`.

### compact
`fault compact <test vector json>`

This performs static compaction on the generated test vectors by reducing the test vectors count while keeping the same coverage.

For more options, you can invoke `fault compact --help`.

### tap
`fault tap --clock <clockName> --reset <resetName> <chained netlist>`

Tap adds JTAG interface to a chained netlist. Currently, two scan chains are supported: the boundary cell scan chain and the internal registers chain. Tap supports the IEEE 1149.1 four mandatory: Extest, Bypass, Sample, and Preload. Also, it has been extended to support ScanIn (4'b 0100) instruction to select the internal register chain.   

For more information on the supported instructions, check the example [testbench](Tests/Testbenches/TestTap.sv).

For more options, you can invoke `fault tap --help`.

# License
Phi is available under the Apache 2.0 License.

# References
- Z. Navabi, Digital System Test and Testable Design : Using Hdl Models and Architectures. 2010;2011;. DOI: 10.1007/978-1-4419-7548-5.
[Book](https://ieeexplore.ieee.org/book/5266057)
- Shinya Takamaeda-Yamazaki: Pyverilog: A Python-based Hardware Design Processing Toolkit for Verilog HDL, 11th International Symposium on Applied Reconfigurable Computing (ARC 2015) (Poster), Lecture Notes in Computer Science, Vol.9040/2015, pp.451-460, April 2015.
[Paper](http://link.springer.com/chapter/10.1007/978-3-319-16214-0_42)

# Publication
Mohamed Gaber, Manar Abdelatty, and Mohamed Shalan, "Fault, an Open Source DFT Toolchain", Article No.13, Workshop on Open-Source EDA Technology (WOSET), 2019.
[Paper](https://woset-workshop.github.io/PDFs/2019/a13.pdf)

# Detailed installation instructions
You can try [INSTALLING.md](INSTALLING.md) for full installation instructions.
