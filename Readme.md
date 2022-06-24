# 🧪 Fault
![Swift 5.2+](https://img.shields.io/badge/Swift-5.2-orange?logo=swift) ![Docker Image Available for x86-64](https://img.shields.io/static/v1?logo=docker&label=docker&message=x86_64) ![AppImage Available for Linux x86-64](https://img.shields.io/static/v1?label=appimage&message=x86_64&color=blue)

Fault is a complete open source design for testing (DFT) Solution that includes automatic test pattern generation for netlists, scan chain stitching, synthesis scripts and a number of other convenience features.

# Quick Setup/Walkthrough
You may refer to the [wiki](https://github.com/Cloud-V/Fault/wiki) for quick setup instructions (and a small walkthrough!) if you're into that.

## Detailed installation instructions
If you don't feel like using (or can't use) Docker, you can try [Installing.md](./Installing.md) for full installation instructions.

# Running
## Subcommands
### synth
Synth is a synthesis script included with Fault that generates both a netlist and a cut-away version.

To run it, `fault synth --top <your-top-module> --liberty <your-liberty-file> <your-file>`. 

For more options, you can invoke `fault synth --help`.

### cut
`fault cut <your-netlist>`

This exposes the D-flipflops as ports for use with the main script.

For more options, you can invoke `fault cut --help`.

### main
`fault --cellModel <your-cell-models> <your-file>`.

A set of assumptions are made about the input file:
* It is a netlist
* It is flattened (there is only one module with no submodules)
* The flipflops have been cut away and replaced with outputs and inputs.

Generated test vectors are printed to stdout by default, but you can use `-o <file>` (or simply redirect the output).

For more options, you can invoke `fault --help`.

### chain
`fault chain --liberty <your-liberty-file> --clock <clockName> --reset <resetName> <--activeLow> <your-file>`.

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
`fault tap --liberty <liberty> [--cellModel <cell model>] --clock <clockName> --reset <resetName> <chained netlist>`

Tap adds JTAG interface to a chained netlist. Currently, two scan chains are supported: the boundary cell scan chain and the internal registers chain. Tap supports the IEEE 1149.1 four mandatory: Extest, Bypass, Sample, and Preload. Also, it has been extended to support ScanIn (4'b 0100) instruction to select the internal register chain.   

A cell model can optionally be passed to verify the tap.

For more information on the supported instructions, check the example [testbench](Tests/Testbenches/TestTap.sv).

For more options, you can invoke `fault tap --help`.

# Copyright & Licensing
All rights reserved ©2018-2022 The American University in Cairo and other contributors. Fault is available under the Apache 2.0 License: See `License`.

SOFTWARE INCLUDED WITH FAULT DISTRIBUTIONS, I.E. ATALANTA AND PODEM, WHILE FREE TO DISTRIBUTE, ARE PROPRIETARY, AND MAY NOT BE USED FOR COMMERCIAL PURPOSES.

# References
- Z. Navabi, Digital System Test and Testable Design : Using Hdl Models and Architectures. 2010;2011;. DOI: 10.1007/978-1-4419-7548-5.
[Book](https://ieeexplore.ieee.org/book/5266057)
- Shinya Takamaeda-Yamazaki: Pyverilog: A Python-based Hardware Design Processing Toolkit for Verilog HDL, 11th International Symposium on Applied Reconfigurable Computing (ARC 2015) (Poster), Lecture Notes in Computer Science, Vol.9040/2015, pp.451-460, April 2015.
[Paper](http://link.springer.com/chapter/10.1007/978-3-319-16214-0_42)

# Publication(s)
- M. Abdelatty, M. Gaber, M. Shalan, "Fault: Open Source EDA’s Missing DFT Toolchain," IEEE Design & Test Magazine. April 2021. [Paper](https://ieeexplore.ieee.org/document/9324799)
- Mohamed Gaber, Manar Abdelatty, and Mohamed Shalan, "Fault, an Open Source DFT Toolchain," Article No.13, Workshop on Open-Source EDA Technology (WOSET), 2019.
[Paper](https://woset-workshop.github.io/PDFs/2019/a13.pdf)


