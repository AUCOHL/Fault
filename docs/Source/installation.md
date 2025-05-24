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

To alleviate the pain of building Fault itself, we provide pre-built
binary Python wheels on PyPI (requiring Python 3.8+ and either macOS or
GNU/Linux): The short version is `python3 -m pip install fault-dft`. You will
need to install all other utilities on your own however.

### Runtime Dependencies

- [Python 3.8+](https://www.python.org/downloads/) with PIP and venv - available in most package managers
- [Yosys](https://github.com/yosyshq/yosys) - available in most package managers
- [IcarusVerilog](https://steveicarus.github.io/iverilog/usage/installation.html)
  - Working with the IHP Open PDK (ihp-sg13g2) requires the ***absolute latest development version*** of IcarusVerilog.
  - You WILL need to build it from source and install it.
- [Quaigh](https://github.com/coloquinte/quaigh) (Optional but really recommended) - `cargo install quaigh`
  - You can get `cargo` by installing Rust -- https://www.rust-lang.org/tools/install
- [Atalanta](https://github.com/hsluoyz/atalanta) (Proprietary, optional)
- [NTU EE PODEM](https://github.com/donn/VLSI-Testing) (Proprietary, optional)

### Build Dependencies

If you're looking to build it on your own, you will need:

* [Swift 5.6+](https://swift.org) and the Swift Package Manager
  * + a compatible version of Clang (included)
