#!/usr/bin/env swift
import Foundation

extension String {
    func shOutput() -> (terminationStatus: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["sh", "-c", self]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
        } catch {
            print("Could not launch task `\(self)': \(error)")
            exit(EX_UNAVAILABLE)
        }
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)

        return (terminationStatus: task.terminationStatus, output: output!)
    }
}

let gitVersion = "git describe --always --tags".shOutput(
    ).output.trimmingCharacters(in: .whitespacesAndNewlines)

enum Action {
    case install
    case uninstall
}

let env = ProcessInfo.processInfo.environment
var action: Action = .install
var path = env["INSTALL_DIR"] ?? "\(env["HOME"]!)/bin"

if CommandLine.arguments.count > 1 {
    print("Usage: INSTALL_DIR=<path>(optional) \(CommandLine.arguments[0])")
    exit(EX_USAGE)
}

if action == .install {
    print("Checking dependencies...")

    let iverilog = "iverilog -V".shOutput()
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

    let yosys = "yosys -V".shOutput()
    if yosys.terminationStatus != EX_OK {
        print("Warning: Yosys does not seem to be installed.")
    } else {
        let components = yosys.output.components(separatedBy: " ")
        if components[1].compare("0.7", options: .numeric) == .orderedAscending {
            print("Warning: Yosys may be out of date. (Recommended ver: 0.7)")
        }
    }


    print("Installing Fault (\(gitVersion))...")

    print("Compiling...")
    let compilationResult = "swift build".shOutput().terminationStatus
    if compilationResult != EX_OK {
        print("Compiling Fault failed.")
        exit(EX_DATAERR)
    }

    let folder = "mkdir -p '\(path)'".shOutput().terminationStatus
    if folder != EX_OK {
        print("Could not create folder.")
        exit(EX_CANTCREAT)
    }

    let internalFolder = "mkdir -p '\(path)/FaultInstall'".shOutput().terminationStatus
    if internalFolder != EX_OK {
        print("Could not create folder.")
        exit(EX_CANTCREAT)
    }

    let launchScript = """
    #!/bin/sh

    export FAULT_INSTALL_PATH="\(path)"
    export FAULT_INSTALL="$FAULT_INSTALL_PATH/FaultInstall"
    export FAULT_VER="\(gitVersion)"

    if [ "$1" == "uninstall" ]; then
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
    let _ = "cp -r Tech/ '\(path)/FaultInstall/Tech'".shOutput().terminationStatus
    let _ = "cp -r Submodules/Pyverilog '\(path)/FaultInstall/Pyverilog'".shOutput().terminationStatus

    print("Installed.")
}