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

if CommandLine.arguments.count != 2 {
    print("Usage: ./synth.swift <file>")
    exit(EX_USAGE)
}

let file = CommandLine.arguments[1]
let output = "Netlists/" + file + ".netlist.v"
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

# flatten
flatten; opt

# mapping flip-flops to mycells.lib
dfflibmap -liberty Tech/osu035/osu035_stdcells.lib

# mapping logic to mycells.lib
abc -liberty Tech/osu035/osu035_stdcells.lib

write_verilog \(output)
"""

let _ = "mkdir -p \(NSString(string: output).deletingLastPathComponent)".sh()
let result = "echo '\(script)' | yosys".sh()

exit(Int32(result))
