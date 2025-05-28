# Installation

In order to use Fault, you have three options:

- Using the Docker Image (Windows, macOS, Linux)
- Using Nix (macOS, Linux)
- Bring-your-own-dependencies (macOS, Linux)

## Using the Docker Image

Docker is software working at the OS level that allows small environments called
"containers" to be run at-will.

It works on Windows, macOS and Linux, where for the first two, a Linux virtual
machine is used.

For instructions on how to install Docker, check
[Docker's website](https://docs.docker.com/install/).

### Getting the Fault Docker image

After installing Docker, run the following command in your terminal of choice:

```sh
docker pull ghcr.io/aucohl/fault:latest
```

You can then run Fault commands using that image. For example, to run
`fault --version`:

```sh
docker run -ti --rm ghcr.io/aucohl/fault:latest fault --version
```

This should print something like `0.9.4`.

If you see that, you have successfully set the Fault environment up on your
machine.

To use the current folder inside the Docker container, you need to add these
options to the command:

```sh
-v </path/to/folder>:</path/to/folder> -w </path/to/folder>
```

Obviously, replacing `</path/to/folder>` with your current path. For example, if
your current folder is `/Users/me/Code`, your options would be
`-v /Users/me/Code:/Users/me/Code -w /Users/me/Code`.

```{tip}
You can add as many `-v`s as you want to mount multiple directories.
```

This makes the final command:

```sh
docker run -ti -v </path/to/folder>:</path/to/folder> -w </path/to/folder> --rm ghcr.io/aucohl/fault:latest fault --version
```

## Using Nix 

Nix is a declarative utility that takes a unique approach to package management
and system configuration.

To install Nix, follow OpenLane 2's Nix installation guide at
https://openlane2.readthedocs.io/en/stable/getting_started/common/nix_installation/index.html.

Afterwards, to make the `fault` command (and the requisite `nl2bench` tool for
using alternative ATPGs) available in PATH, you can simply invoke
`nix profile install github:AUCOHL/Fault`.

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
