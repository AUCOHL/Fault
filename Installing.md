# Dependencies
* Git
* Clang 12.0+
* Swift 5.2+
* Python 3.6+ with PIP
* Yosys 0.9+
    * 0.22+ recommended
* Icarus Verilog 10.2+
* Pyverilog
* Atalanta (Optional)
* PODEM (Optional)

# Installing
You need a Swift-compatible operating system (i.e. macOS or Linux). The Swift version of Windows isn't mature enough for this just yet.

Again, if you're on Windows (or you're too lazy to follow these instructions,) you can use the Docker container.

## macOS
macOS 11 Big Sur or higher is required.

Install the latest Xcode from the Mac App Store.

Use [Homebrew](https://brew.sh).

`brew install python yosys icarus-verilog`

## Linux
You need to fulfill the dependencies listed above.

### Ubuntu
Ubuntu 20.04 or higher is required.

Using apt:

`sudo apt-get install git clang python3 python3-dev yosys iverilog`

Then install the Swift programming language: instructions are on [swift.org](https://swift.org/download/#using-downloads).

## Both
You'll need Pyverilog: In the root of the repository, type:

```sh
python3 -m pip install -r ./requirements.txt
```

You can optionally install Atalanta and PODEM if you want to use them for test vector generation. Please note they fall under proprietary licenses and are not open-source.

```bash
EXEC_PREFIX=</usr/local/bin> sudo $(which swift) ./atalanta_podem_build.swift
```

# Installation
Then simply invoke `swift install.swift`. This will install it to `~/bin` by default. You can customize this installation directory by executing `INSTALL_DIR=<path> swift ./install.swift`.

You may need to add `~/bin` to the PATH environment variable depending on your OS.

To uninstall this, you can simply invoke `fault uninstall`.

## Without installation
### Building
With everything set up properly, run `swift build -c release` from the root of the repository. That'll be it: You can find the binary under `.build/release/Fault`, but you can also run it simply by typing `swift run Fault`.

### Notes
Both `fault uninstall` and `fault -V` will not function. Please note you will need to install all the dependencies anyway.
