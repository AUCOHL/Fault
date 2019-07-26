#!/usr/bin/env swift
import Foundation

extension String {
    func sh() -> Int {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["sh", "-c", self]
        task.launch()
        task.waitUntilExit()
        return Int(task.terminationStatus)
    }
    func shOutput() -> (terminationStatus: Int32, output: String) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["sh", "-c", self]

        let pipe = Pipe()
        task.standardOutput = pipe

        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)

        return (terminationStatus: task.terminationStatus, output: output!)
    }
}

let gitVersion = "git describe --always --tags".shOutput().output.dropLast()

enum Action {
    case install
    case uninstall
}

let env = ProcessInfo.processInfo.environment
var action: Action = .install
var path = "\(env["HOME"]!)/bin"
var opt = true

if CommandLine.arguments.count == 1 {
}
else if CommandLine.arguments.count == 2 {
    // second argument is path
    path = CommandLine.arguments[1]
}
else if CommandLine.arguments.count == 3 {
    // second argument is path, third argument is 'uninstall'
    path = CommandLine.arguments[1]
    if CommandLine.arguments[2] != "uninstall" {
        opt = false
    } else {
        action = .uninstall
    }
}

if !opt {
    print("Usage: \(CommandLine.arguments[0]) <path (optional if installing)> <uninstall (optional)>")
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
    let compilationResult = "swift build -c release".sh()
    if compilationResult != EX_OK {
        print("Compiling Fault failed.")
        exit(EX_DATAERR)
    }

    let folder = "mkdir -p '\(path)'".sh()
    if folder != EX_OK {
        print("Could not create folder.")
        exit(EX_CANTCREAT)
    }

    let internalFolder = "mkdir -p '\(path)/FaultInstall'".sh()
    if internalFolder != EX_OK {
        print("Could not create folder.")
        exit(EX_CANTCREAT)
    }

    let launchScript = """
    #!/bin/sh

    export FAULT_INSTALL_PATH="\(path)"
    export FAULT_VER="\(gitVersion)"

    "\(path)/FaultInstall/fault" $@
    rm -f parser.out parsetab.py
    rm -rf __pycache__
    """

    let _ = "echo '\(launchScript)' > '\(path)/fault'".sh()
    let _ = "chmod +x '\(path)/fault'".sh()

    let _ = "cp .build/release/Fault '\(path)/FaultInstall/fault'".sh()
    let _ = "cp -r Tech/ '\(path)/FaultInstall/Tech'".sh()
    let _ = "cp -r Submodules/Pyverilog '\(path)/FaultInstall/Pyverilog'".sh()

    print("Installed.")
} else {
    print("Uninstalling Fault (\(gitVersion))...")

    let internalFolder = "rm -rf '\(path)/FaultInstall'".sh()
    if internalFolder != EX_OK {
        print("Could not delete folder.")
        exit(EX_NOINPUT)
    }

    let shScript = "rm -f '\(path)/fault'".sh()
    if shScript != EX_OK {
        print("Could not delete script.")
        exit(EX_NOINPUT)
    }

    print("Uninstalled.")
}