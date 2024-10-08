// Copyright (C) 2019 The American University in Cairo
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import BigInt
import Collections
import ArgumentParser
import CoreFoundation // Not automatically imported on Linux
import Defile
import Foundation
import PythonKit
import Yams

let VERSION = "0.7.1"

var env = ProcessInfo.processInfo.environment
let iverilogBase = env["FAULT_IVL_BASE"] ?? "/usr/local/lib/ivl"
let iverilogExecutable = env["FAULT_IVERILOG"] ?? env["PYVERILOG_IVERILOG"] ?? "iverilog"
let vvpExecutable = env["FAULT_VVP"] ?? "vvp"
let yosysExecutable = env["FAULT_YOSYS"] ?? "yosys"

_ = [ // Register all RNGs
    SwiftRNG.registered,
    LFSR.registered,
    PatternGenerator.registered,
]
_ = [ // Register all TVGens
    Atalanta.registered,
    Quaigh.registered,
    PODEM.registered,
]

let yosysTest = "'\(yosysExecutable)' -V".sh(silent: true)
if yosysTest != EX_OK {
    Stderr.print("Yosys must be installed to PATH on your computer for Fault to work. Fault will now quit.")
    exit(EX_UNAVAILABLE)
}

let pythonVersions = {
    // Test Yosys, Python
    () -> (python: String, pyverilog: String) in
    do {
        let pythonVersion = try Python.attemptImport("platform").python_version()
        let sys = Python.import("sys")
        if let pythonPath = env["PYTHONPATH"] {
            sys.path.append(pythonPath)
        } else {
            let pythonPathProcess = "python3 -c \"import sys; print(':'.join(sys.path), end='')\"".shOutput()
            let pythonPath = pythonPathProcess.output
            let pythonPathComponents = pythonPath.components(separatedBy: ":")
            for component in pythonPathComponents {
                sys.path.append(component)
            }
        }

        let pyverilogVersion = try Python.attemptImport("pyverilog").__version__
        return (python: "\(pythonVersion)", pyverilog: "\(pyverilogVersion)")
    } catch {
        Stderr.print("\(error)")
        exit(EX_UNAVAILABLE)
    }
}() // Just to check

struct Fault: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Open-source EDA's missing DFT Toolchain",
        subcommands: [ATPG.self, Cut.self, Synth.self, Assemble.self, Tap.self, Chain.self],
        defaultSubcommand: ATPG.self
    )
}

Fault.main()
