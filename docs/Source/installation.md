# Installation

In order to use Fault, you have three options:

- Using Nix (macOS, Linux)
- Using the Docker Image (Windows, macOS, Linux)
- Bring-your-own-dependencies (macOS, Linux)

> Docker images for Fault are only available on x86-64 devices.

## Using Nix 

Nix is a declarative utility that takes a unique approach to package management
and system configuration.

To install Nix, follow OpenLane 2's Nix installation guide at
https://openlane2.readthedocs.io/en/stable/getting_started/common/nix_installation/index.html.

Afterwards, running Fault is simply `nix run github:AUCOHL/Fault`. To make
the `fault` command available in path, you can
`nix profile install github:AUCOHL/Fault`.

## Docker

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
`fault -V`:

```sh
docker run -ti --rm ghcr.io/aucohl/fault:latest fault -V
```

This should print something like
`Fault X.X.X. ©The American University in Cairo 2019-2022. All rights reserved.`.
If you see that, you have successfully set the Fault environment up on your
machine.

To use the current folder inside the Docker container, you need to add these
options to the command:

```sh
-v </path/to/folder>:/mount -w /mount
```

Obviously, replacing `</path/to/folder>` with your current path. For example, if
your current folder is `/Users/me/Code`, your options would be
`-v /Users/me/Code:/mount -w /mount`.

This makes the final command:

```sh
docker run -ti -v </path/to/folder>:/mount -w /mount --rm ghcr.io/cloud-v/fault:latest fault -V
```

### Tip on Unix-based systems

You can set what is known a shell alias so you can avoid typing the long command
repeatedly.

```sh
alias fault='docker run -tiv `pwd`:`pwd` -w `pwd` --rm ghcr.io/aucohl/fault:latest fault'
```

Then, you can invoke fault's options, by directly typing `Fault`. An equivalent
to the command above for example would be:

```
fault -V
```

Note that this command mounts the existing folder with an identical path, and
not to `/mount`.

If you're on Windows, this section will not work as paths on that operating
system are incompatible with the Linux virtual machine. Not to mention, no
default Windows shells support bash aliases.

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
- Atalanta (Optional)
- PODEM (Optional)

### OS-Specific Instructions

#### macOS
macOS 12 or higher is required.

Install the latest Xcode from the Mac App Store.

Use [Homebrew](https://brew.sh).

`brew install python yosys icarus-verilog`

#### Ubuntu GNU/Linux

Ubuntu 20.04 or higher is required.

Using apt:

`sudo apt-get install git clang python3 python3-dev python3-pip python3-venv yosys iverilog`

Then install the Swift programming language: instructions are on [swift.org](https://swift.org/download/#using-downloads).
