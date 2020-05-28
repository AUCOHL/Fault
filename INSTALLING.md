# Dependencies
* Swift 5.0+
* Python 3.6+ with PIP
* Yosys 0.7+
* Icarus Verilog 10.2+
* Pyverilog (dev)
* Atalanta

# Installing
You need a Swift-compatible operating system (i.e. macOS or Linux).

Again, if you're on Microsoft Windows (or you're too lazy to follow these instructions,) you can use the Docker container.

## macOS
macOS 10.13 High Sierra or higher is required.

Install the latest Xcode from the Mac App Store.

Use [Homebrew](https://brew.sh).

`brew install python yosys icarus-verilog`

## Debian-based Linuces (e.g. Ubuntu)
Using apt:

`sudo apt-get install git clang python3 python3-dev yosys`

Then install the Swift programming language: instructions are on [swift.org](https://swift.org/download/#using-downloads).

Notice how Icarus Verilog is excluded. This is because as of the time of writing, there is no version of Swift on a version of Ubuntu that has Icarus Verilog 10.2 or above. Which is ridiculous. You'll have to build it from source. First, grab these dev dependencies:

`sudo apt-get install curl autoconf make gperf flex bison`

Then just run this in a terminal instance:

```bash
EXEC_PREFIX=</usr/local/bin> sudo ./iverilog_build.swift
```

## Both
You'll need the dev branch of Pyverilog install with pip.

`python3 -m pip install https://github.com/PyHDI/Pyverilog/archive/develop.zip`

You'll also need to install Atalanta if you want to use it for test vector generation.

```bash
EXEC_PREFIX=</usr/local/bin> sudo ./atalanta_build.swift
```

# Installation
Type `git submodule update --init --recursive` in the terminal to initialize submodules.

Then simply invoke `swift install.swift`. This will install it to `~/bin` by default. You can customize this installation directory by executing `INSTALL_DIR=<path> swift install.swift`.

You may need to add `~/bin` to path depending on your OS.

To uninstall this, you can simply invoke `fault uninstall`.

# Usage without installation
Osu035 will not be used automatically and `fault uninstall`, `fault -V` will not function.
