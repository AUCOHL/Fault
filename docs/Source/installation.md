# Installation

In order to use Fault, you have three options:

- Using Nix (macOS, Linux)
- Using the Docker Image (Windows, macOS, Linux)
- Bring-your-own-dependencies (macOS, Linux)

## Using Nix 

Nix is a declarative utility that takes a unique approach to package management
and system configuration.

To install Nix, follow OpenLane 2's Nix installation guide at
https://openlane2.readthedocs.io/en/stable/getting_started/common/nix_installation/index.html.

Afterwards, to make the `fault` command (and the requisite `nl2bench` tool for
using alternative ATPGs) available in PATH, you can simply invoke
`nix profile install github:AUCOHL/Fault`.

## Docker

We no longer provide Docker images ourselves. We intend to work with
[IIC-OSIC-TOOLS](https://github.com/iic-jku/IIC-OSIC-TOOLS) to make Fault
available via Docker and will update this document when we do.

## Bring-your-own-dependencies

Fault requires a number of dependencies that you may elect to install manually.

You need a Unix-based, Swift-compatible operating system. 

Again, if you're on Windows (or you're too lazy to follow these instructions,)
you can use the Docker container.

We will not be supporting this option as too many things can go wrong, but here
are some pointers nevertheless.

### Build Dependencies

* [Swift 5.8+](https://swift.org) and the Swift Package Manager
  * + a compatible version of Clang (included)
* Git

### Run-time Dependencies

- [Yosys](https://github.com/yosyshq/yosys)
- [IcarusVerilog](https://steveicarus.github.io/iverilog/usage/installation.html)
  - You will need to set the environment variable `FAULT_IVL_BASE` to point to
    the `ivl` directory installed by IcarusVerilog.
- [Python 3.8+](https://www.python.org/downloads/) with PIP and venv
  - You will need to set the environment variable `PYTHON_LIBARY` to point to
    the `.so`/`.dylib` file for Python.
  - [Pyverilog](https://github.com/pyverilog/pyverilog)
  - [nl2bench](https://github.com/donn/nl2bench) (Required if using Quaigh or Atalanta)
- [Quaigh](https://github.com/coloquinte/quaigh) (Optional but really recommended)
- [Atalanta](https://github.com/hsluoyz/atalanta) (Optional)
- [NTU EE PODEM](https://github.com/donn/VLSI-Testing) (Optional)
