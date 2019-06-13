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
}

let env = ProcessInfo.processInfo.environment
let defaultLiberty = env["FAULT_INSTALL_PATH"] != nil

print(defaultLiberty)

if CommandLine.arguments.count != 4 && !(defaultLiberty && CommandLine.arguments.count == 3) {
    print("Usage: ./synth.swift <rtl> <output> <liberty-file>")
    if defaultLiberty {
        print("If a liberty file is not provided, osu035 will be used.")
    }
    exit(EX_USAGE)
}

let file = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let liberty = CommandLine.arguments.count == 3 ? "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_stdcells.lib" : CommandLine.arguments[3]
let script = """
read_verilog \(file)

# check design hierarchy
hierarchy

# translate processes (always blocks)
proc; opt

# detect and optimize FSM encodings
fsm; opt

# implement memories (arrays)
memory; opt

# convert to gate logic
techmap; opt

# expose dff
expose -cut -evert-dff; opt

# flatten
flatten; opt

# mapping flip-flops to mycells.lib
dfflibmap -liberty \(liberty)

# mapping logic to mycells.lib
abc -liberty \(liberty)

write_verilog \(output)
"""

let _ = "mkdir -p \(NSString(string: output).deletingLastPathComponent)".sh()
let result = "echo '\(script)' | yosys".sh()

exit(Int32(result))
