#!/usr/bin/env swift
import Foundation

var env = ProcessInfo.processInfo.environment
let iverilogBase = env["FAULT_IVL_BASE"] ?? "/usr/local/lib/ivl"
let iverilogExecutable = env["FAULT_IVERILOG"] ?? env["PYVERILOG_IVERILOG"] ?? "iverilog"
let vvpExecutable = env["FAULT_VVP"] ?? "vvp"
let yosysExecutable = env["FAULT_YOSYS"] ?? "yosys"
let atalantaExecutable = env["FAULT_ATALANTA"] ?? "atalanta"
let podemExecutable = env["FAULT_PODEM"] ?? "atpg"

extension String {
    func shOutput() -> (terminationStatus: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["sh", "-c", self]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            print("Could not launch task `\(self)': \(error)")
            exit(EX_UNAVAILABLE)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8)

        return (terminationStatus: task.terminationStatus, output: output!)
    }

    func sh(silent: Bool = false) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["sh", "-c", self]

        if (silent) {
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
        }

        do {
            try task.run()
        } catch {
            print("Could not launch task `\(self)': \(error)")
            exit(EX_UNAVAILABLE)
        }

        task.waitUntilExit()

        return task.terminationStatus
    }
}

enum Action {
    case install
    case uninstall
}

var action: Action = .install
var path = env["INSTALL_DIR"] ?? "\(env["HOME"]!)/bin"

if CommandLine.arguments.count > 1 {
    print("Usage: INSTALL_DIR=<path>(optional) \(CommandLine.arguments[0])")
    exit(EX_USAGE)
}

let coreCount = ProcessInfo.processInfo.activeProcessorCount

if action == .install {
    print("Checking dependencies…")

    let python3 = "python3 -V".shOutput()
    if python3.terminationStatus != EX_OK {
        print("python3 not found in PATH. The setup will fail.")
        exit(EX_UNAVAILABLE)
    } else {
        let components = python3.output.components(separatedBy: " ")
        if components[1].compare("3.6", options: .numeric) == .orderedAscending {
            print("Warning: Python 3 may be out of date. (Recommended ver: 3.6+)")
        }
    }


    let ivlPath = "[ -d '\(iverilogBase)' ]".shOutput()
    if ivlPath.terminationStatus != EX_OK {
        print("Warning: The directory \(iverilogBase) was not found. You may need to export the environment variable 'FAULT_IVL_BASE' when using Fault.")
    }

    let iverilog = "'\(iverilogExecutable)' -B '\(iverilogBase)' -V".shOutput()
    if iverilog.terminationStatus != EX_OK {
        print("Warning: Cannot detect an installation of Icarus Verilog. 'iverilog' will need to be in PATH when using Fault.")
    } else {
        let components = iverilog.output.components(separatedBy: " ")
        if components[3].compare("10.2", options: .numeric) == .orderedAscending {
            print("Warning: Icarus Verilog may be out of date. (Recommended ver: 10.2)")
        }
    }

    let yosys = "'\(yosysExecutable)' -V".shOutput()
    if yosys.terminationStatus != EX_OK {
        print("Warning: Yosys does not seem to be installed. 'yosys' will need to be in PATH when using Fault.")
    } else {
        let components = yosys.output.components(separatedBy: " ")
        if components[1].compare("0.7", options: .numeric) == .orderedAscending {
            print("Warning: Yosys may be out of date. (Recommended ver: 0.7)")
        }
    }

    let atalanta = "'\(atalantaExecutable)'".shOutput()
    if atalanta.terminationStatus != EX_OK {
        print("Optional component atalanta does not seem to be installed.")
    }

    let podem = "'\(podemExecutable)'".shOutput()
    if podem.terminationStatus != EX_OK {
        print("Optional component podem does not seem to be installed.")
    }
    
    print("Installing Fault…")

    let fileManager = FileManager()

    print("Compiling…")
    let compilationResult = "swift build -c release -j \(coreCount)".sh()
    if compilationResult != EX_OK {
        print("Compiling Fault failed with exit code \(compilationResult).")
        exit(EX_DATAERR)
    }

    do {
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
    } catch {
        print("Could not create folder '\(path)'")
        exit(EX_CANTCREAT)
    }

    do {
        try fileManager.createDirectory(atPath: "\(path)/FaultInstall", withIntermediateDirectories: true)
    } catch {
        print("Could not create folder '\(path)'")
        exit(EX_CANTCREAT)
    }

    let venvPath = "\(path)/FaultInstall/venv"
    
    let venvCreate = "python3 -m venv '\(venvPath)'".sh()
    if venvCreate != EX_OK {
        print("Could not create Python virtual environment: process failed with exit code \(venvCreate).")
        exit(EX_CANTCREAT)
    }
    
    let pipInstall = "'\(venvPath)/bin/python3' -m pip install -r ./requirements.txt".sh()
    if pipInstall != EX_OK {
        print("Could not install Python dependencies: process failed with exit code \(pipInstall).")
        exit(EX_UNAVAILABLE)
    }

    let venvLibPath = "\(venvPath)/lib"
    let venvLibVersions = try! fileManager.contentsOfDirectory(atPath: venvLibPath)
    let venvLibVersion = "\(venvLibPath)/\(venvLibVersions[0])/site-packages"

    let libPythonProcess = "\(venvPath)/bin/find_libpython".shOutput()
    if libPythonProcess.terminationStatus != EX_OK {
        print("Failed to extract Python library.")
        exit(EX_UNAVAILABLE)
    }

    let libPython = libPythonProcess.output


    let launchScript = """
    #!/bin/bash
    set -e

    export FAULT_INSTALL_PATH="\(path)"
    export FAULT_INSTALL="$FAULT_INSTALL_PATH/FaultInstall"

    export FAULT_IVL_BASE="\(iverilogBase)"
    export FAULT_IVERILOG="\(iverilogExecutable)"
    export FAULT_VVP="\(vvpExecutable)"
    export FAULT_YOSYS="\(yosysExecutable)"
    export FAULT_ATALANTA="\(atalantaExecutable)"
    export FAULT_PODEM="\(podemExecutable)"

    if [ "uninstall" = "$1" ]; then
        echo "Uninstalling Fault…"
        echo "Removing installation…"
        set -x
        rm -rf "$FAULT_INSTALL"
        set +x
        echo "Removing fault script…"
        set -x
        rm -f "$0"
        set +x
        echo "Done."
        exit 0
    fi
    export PYTHONPATH=\(venvLibVersion)
    export PYTHON_LIBRARY=\(libPython)
    "$FAULT_INSTALL/fault" $@
    rm -f parser.out parsetab.py
    rm -rf __pycache__
    """

    let faultScriptPath = "\(path)/fault"
    if !fileManager.createFile(
        atPath: faultScriptPath,
        contents: launchScript.data(using: .utf8),
        attributes: [.posixPermissions: 0o755]
    ) {
        print("Failed to create Fault launch script at \(faultScriptPath).")
        exit(EX_CANTCREAT)
    }

    let faultBinaryPath = "\(path)/FaultInstall/fault"
    do {
        try fileManager.copyItem(
            atPath: ".build/release/Fault",
            toPath: faultBinaryPath
        )
    } catch {
        print("Failed to copy Fault binary to \(faultBinaryPath).")
        exit(EX_CANTCREAT)
    }

    print("Installed.")
}