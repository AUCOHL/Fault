# Dependencies
* Swift 5.2+
* Python 3.6+ with PIP
* Yosys 0.7+
* Icarus Verilog 10.2+
* Pyverilog
* Atalanta (Optional)
* PODEM (Optional)

# Installing
You need a Swift-compatible operating system (i.e. macOS or Linux). The Swift version of Windows isn't mature enough for this just yet.

Again, if you're on Windows (or you're too lazy to follow these instructions,) you can use the Docker container.

## macOS
macOS 10.13 High Sierra or higher is required.

Install the latest Xcode from the Mac App Store.

Use [Homebrew](https://brew.sh).

`brew install python yosys icarus-verilog`

## Linux
You need to fulfill these dependencies:
- Git
- Clang
- Python 3.6 or higher (w/ development libraries)
- Yosys 0.7 or higher
- Icarus Verilog 10.2 or higher

### Ubuntu
Using apt:

`sudo apt-get install git clang python3 python3-dev yosys iverilog`

Then install the Swift programming language: instructions are on [swift.org](https://swift.org/download/#using-downloads).

### If you're using Ubuntu 18.04 or lower…
The version of Icarus Verilog you just installed is insufficient, as 10.2 has a number of critical bugfixes that are required for Fault to run. You'll have to build it from source. First, grab these dev dependencies:

`sudo apt-get install curl autoconf make gperf flex bison`

Then just run this in a terminal instance:

```bash
EXEC_PREFIX=</usr/local/bin> sudo ./iverilog_build.swift
```

## Both
You'll need Pyverilog

`python3 -m pip install pyverilog`

You can optionally install Atalanta if you want to use it for test vector generation.

```bash
EXEC_PREFIX=</usr/local/bin> sudo ./atalanta_build.swift
```

# Installation
Type `git submodule update --init --recursive` in the terminal to initialize submodules.

Then simply invoke `swift install.swift`. This will install it to `~/bin` by default. You can customize this installation directory by executing `INSTALL_DIR=<path> swift install.swift`.

You may need to add `~/bin` to path depending on your OS.

To uninstall this, you can simply invoke `fault uninstall`.

# Usage without installation
Both `fault uninstall` and `fault -V` will not function.

You can use Fault without installing by invoking `swift run Fault` in place of `fault`. Please note that you still need all the other dependencies anyway.