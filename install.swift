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

if action == .install {
    print("Checking dependencies…")

    let ivlPath = "[ -d '\(iverilogBase)' ]".shOutput()
    if ivlPath.terminationStatus != EX_OK {
        print("Warning: The directory \(iverilogBase) was not found.")
    }

    let iverilog = "'\(iverilogExecutable)' -B '\(iverilogBase)' -V".shOutput()
    if iverilog.terminationStatus != EX_OK {
        print("Warning: Icarus Verilog does not seem to be installed.")
    } else {
        let components = iverilog.output.components(separatedBy: " ")
        if components[3].compare("10.2", options: .numeric) == .orderedAscending {
            print("Warning: Icarus Verilog may be out of date. (Recommended ver: 10.2)")
        }
    }

    let python3 = "python3 -V".shOutput()
    if python3.terminationStatus != EX_OK {
        print("Warning: Python 3 does not seem to be installed.")
    } else {
        let components = python3.output.components(separatedBy: " ")
        if components[1].compare("3.6", options: .numeric) == .orderedAscending {
            print("Warning: Python 3 may be out of date. (Recommended ver: 3.6)")
        }
    }

    let yosys = "'\(yosysExecutable)' -V".shOutput()
    if yosys.terminationStatus != EX_OK {
        print("Warning: Yosys does not seem to be installed.")
    } else {
        let components = yosys.output.components(separatedBy: " ")
        if components[1].compare("0.7", options: .numeric) == .orderedAscending {
            print("Warning: Yosys may be out of date. (Recommended ver: 0.7)")
        }
    }

    let atalanta = "'\(atalantaExecutable)'".shOutput()
    if atalanta.terminationStatus != EX_OK {
        print("Warning: Atalanta does not seem to be installed.")
    }

    let podem = "'\(podemExecutable)'".shOutput()
    if podem.terminationStatus != EX_OK {
        print("Warning: PODEM does not seem to be installed.")
    }
    
    print("Installing Fault…")

    print("Compiling…")
    let compilationResult = "swift build".shOutput()
    if compilationResult.terminationStatus != EX_OK {
        print("Compiling Fault failed.")
        print(compilationResult)
        exit(EX_DATAERR)
    }

    let folder = "mkdir -p '\(path)'".shOutput()
    if folder.terminationStatus != EX_OK {
        print("Could not create folder.")
        exit(EX_CANTCREAT)
    }

    let internalFolder = "mkdir -p '\(path)/FaultInstall'".shOutput()
    if internalFolder.terminationStatus != EX_OK {
        print("Could not create folder.")
        exit(EX_CANTCREAT)
    }

    let launchScript = """
    #!/bin/sh

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

    "$FAULT_INSTALL/fault" $@
    rm -f parser.out parsetab.py
    rm -rf __pycache__
    """

    let _ = "echo '\(launchScript)' > '\(path)/fault'".shOutput().terminationStatus
    let _ = "chmod +x '\(path)/fault'".shOutput().terminationStatus

    let _ = "cp .build/debug/Fault '\(path)/FaultInstall/fault'".shOutput().terminationStatus

    print("Installed.")
}