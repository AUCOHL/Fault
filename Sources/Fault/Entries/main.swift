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
import CommandLineKit
import CoreFoundation // Not automatically imported on Linux
import Defile
import Foundation
import PythonKit
import Yams

let VERSION = "0.7.0"

var env = ProcessInfo.processInfo.environment
let iverilogBase = env["FAULT_IVL_BASE"] ?? "/usr/local/lib/ivl"
let iverilogExecutable = env["FAULT_IVERILOG"] ?? env["PYVERILOG_IVERILOG"] ?? "iverilog"
let vvpExecutable = env["FAULT_VVP"] ?? "vvp"
let yosysExecutable = env["FAULT_YOSYS"] ?? "yosys"

_ = [ // Register all RNGs
    SwiftRNG.registered,
    LFSR.registered,
]
_ = [ // Register all TVGens
    Atalanta.registered,
    PODEM.registered,
]

let subcommands: OrderedDictionary = [
    "synth": (func: synth, desc: "synthesis"),
    "chain": (func: scanChainCreate, desc: "scan chain"),
    "cut": (func: cut, desc: "cutting"),
    "asm": (func: assemble, desc: "test vector assembly"),
    "compact": (func: compactTestVectors, desc: "test vector static compaction"),
    "tap": (func: jtagCreate, desc: "JTAG port insertion"),
    "bench": (func: bench, desc: "verilog netlist to bench format conversion"),
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

func main(arguments: [String]) -> Int32 {
    // MARK: CommandLine Processing

    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let defaultTVCount = "100"
    let defaultTVIncrement = "50"
    let defaultMinimumCoverage = "80"
    let defaultCeiling = "1000"
    let defaultRNG = "swift"

    let version = BoolOption(
        shortFlag: "V",
        longFlag: "version",
        helpMessage: "Prints the current version and exits."
    )
    cli.addOptions(version)

    let help = BoolOption(
        shortFlag: "h",
        longFlag: "help",
        helpMessage: "Prints this message and exits."
    )
    cli.addOptions(help)

    let filePath = StringOption(
        shortFlag: "o",
        longFlag: "output",
        helpMessage: "Path to the output JSON file. (Default: input + .tv.json)"
    )
    cli.addOptions(filePath)

    let svfFilePath = StringOption(
        longFlag: "output-svf",
        helpMessage: "Path to the output SVF file. (Default: input + .tv.svf)"
    )
    cli.addOptions(svfFilePath)

    let faultPointFilePath = StringOption(
        longFlag: "output-faultPoints",
        helpMessage: "Path to the output yml file listing all generated fault points. (Default: nil)"
    )
    cli.addOptions(faultPointFilePath)

    let coverageMetaFilePath = StringOption(
        longFlag: "output-covered",
        helpMessage: "Path to the output yml file listing coverage metadata, i.e., ratio and fault points covered. (Default: nil)"
    )
    cli.addOptions(coverageMetaFilePath)

    let cellsOption = StringOption(
        shortFlag: "c",
        longFlag: "cellModel",
        helpMessage: ".v file describing the cells (Required.)"
    )
    cli.addOptions(cellsOption)

    let testVectorCount = StringOption(
        shortFlag: "v",
        longFlag: "tvCount",
        helpMessage: "Number of test vectors generated (Default: \(defaultTVCount).)"
    )
    cli.addOptions(testVectorCount)

    let testVectorIncrement = StringOption(
        shortFlag: "r",
        longFlag: "increment",
        helpMessage: "Increment in test vector count should sufficient coverage not be reached. (Default: \(defaultTVIncrement).)"
    )
    cli.addOptions(testVectorIncrement)

    let minimumCoverage = StringOption(
        shortFlag: "m",
        longFlag: "minCoverage",
        helpMessage: "Minimum number of fault sites covered percent. Set this to 0 to prevent increments. (Default: \(defaultMinimumCoverage).)"
    )
    cli.addOptions(minimumCoverage)

    let ceiling = StringOption(
        longFlag: "ceiling",
        helpMessage: "Ceiling for Test Vector increments: if this number is reached, no more increments will occur regardless the coverage. (Default: \(defaultCeiling).)"
    )
    cli.addOptions(ceiling)

    let rng = StringOption(
        longFlag: "rng",
        helpMessage: "Type of the RNG used in Internal TV Generation: LFSR or swift. (Default: swift.)"
    )
    cli.addOptions(rng)

    let tvGen = StringOption(
        shortFlag: "g",
        longFlag: "tvGen",
        helpMessage: "Use an external TV Generator: Atalanta or PODEM. (Default: Internal.)"
    )
    cli.addOptions(tvGen)

    let bench = StringOption(
        shortFlag: "b",
        longFlag: "bench",
        helpMessage: "Netlist in bench format. (Required iff generator is set to Atalanta or PODEM.)"
    )
    cli.addOptions(bench)

    let sampleRun = BoolOption(
        longFlag: "sampleRun",
        helpMessage: "Generate only one testbench for inspection, do not delete it."
    )
    cli.addOptions(sampleRun)

    let ignored = StringOption(
        shortFlag: "i",
        longFlag: "ignoring",
        helpMessage: "Inputs,to,ignore,separated,by,commas. (Default: none)"
    )
    cli.addOptions(ignored)

    let holdLow = BoolOption(
        longFlag: "holdLow",
        helpMessage: "Hold ignored inputs to low in the simulation instead of high. (Default: holdHigh)"
    )
    cli.addOptions(holdLow)

    let clock = StringOption(
        longFlag: "clock",
        helpMessage: "clock name to add to --ignoring. (Required.)"
    )
    cli.addOptions(clock)

    let externalTVSet = StringOption(
        longFlag: "externalTVSet",
        helpMessage: ".json file describing an external set of test-vectors to be simulated for coverage, with NO FURTHER GENERATION attempted. (Optional)"
    )
    cli.addOptions(externalTVSet)

    let startingTVSetOpt = StringOption(
        longFlag: "iteratingUpon",
        helpMessage: ".json file of test vectors to start with; iterating further as necessary. (Default: None/empty)"
    )
    cli.addOptions(startingTVSetOpt)

    let defs = StringOption(
        longFlag: "define",
        helpMessage: "define statements to include during simulations. (Default: none)"
    )
    cli.addOptions(defs)

    let include = StringOption(
        longFlag: "inc",
        helpMessage: "Extra verilog models to include during simulations. Comma-delimited. (Default: none)"
    )
    cli.addOptions(include)

    do {
        try cli.parse()
    } catch {
        Stderr.print(error)
        Stderr.print("Invoke fault --help for more info.")
        return EX_USAGE
    }

    if version.value {
        print("Fault \(VERSION). ©The American University in Cairo 2019-2022. All rights reserved.")
        print("Using Python \(pythonVersions.python) and Pyverilog \(pythonVersions.pyverilog).")
        return EX_OK
    }

    if help.value {
        cli.printUsage()
        for (key, value) in subcommands {
            print("To take a look at \(value.desc) options, try 'fault \(key) --help'")
        }
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        Stderr.print("Invalid argument count: (\(args.count)/\(1)) (\(args))")
        Stderr.print("Invoke fault --help for more info.")
        return EX_USAGE
    }

    let randomGenerator = rng.value ?? defaultRNG

    guard
        let tvAttempts = Int(testVectorCount.value ?? defaultTVCount),
        let tvIncrement = Int(testVectorIncrement.value ?? defaultTVIncrement),
        let tvMinimumCoverageInt = Int(minimumCoverage.value ?? defaultMinimumCoverage),
        Int(ceiling.value ?? defaultCeiling) != nil, URNGFactory.validNames.contains(randomGenerator), (tvGen.value == nil) == (bench.value == nil)
    else {
        cli.printUsage()
        return EX_USAGE
    }

    let fileManager = FileManager()
    let file = args[0]
    if !fileManager.fileExists(atPath: file) {
        Stderr.print("File '\(file)' not found.")
        return EX_NOINPUT
    }

    guard let clockName = clock.value else {
        Stderr.print("Option --clock is required.")
        Stderr.print("Invoke fault --help for more info.")
        return EX_USAGE
    }

    guard let cells = cellsOption.value else {
        Stderr.print("Option --cellModel is required.")
        Stderr.print("Invoke fault --help for more info.")
        return EX_USAGE
    }

    if !fileManager.fileExists(atPath: cells) {
        Stderr.print("Cell model file '\(cells)' not found.")
        return EX_NOINPUT
    }
    if !cells.hasSuffix(".v"), !cells.hasSuffix(".sv") {
        Stderr.print(
            "Warning: Cell model file provided does not end with .v or .sv."
        )
    }

    let jsonOutput = filePath.value ?? "\(file).tv.json"
    let svfOutput = svfFilePath.value ?? "\(file).tv.svf"
    var ignoredInputs
        = Set<String>(ignored.value?.components(separatedBy: ",").filter { $0 != "" } ?? [])

    ignoredInputs.insert(clockName)

    let behavior
        = [Simulator.Behavior](
            repeating: holdLow.value ? .holdLow : .holdHigh,
            count: ignoredInputs.count
        )
    let defines
        = Set<String>(defs.value?.components(separatedBy: ",").filter { $0 != "" } ?? [])

    let includeFiles
        = Set<String>(include.value?.components(separatedBy: ",").filter { $0 != "" } ?? [])

    // MARK: Importing Python and Pyverilog

    let parse = Python.import("pyverilog.vparser.parser").parse

    // MARK: Parsing and Processing

    let parseResult = parse([file])
    let ast = parseResult[0]
    let description = ast[dynamicMember: "description"]
    var definitionOptional: PythonObject?

    for definition in description.definitions {
        let type = Python.type(definition).__name__
        if type == "ModuleDef" {
            definitionOptional = definition
            break
        }
    }

    guard let definition = definitionOptional else {
        Stderr.print("No module found.")
        return EX_DATAERR
    }

    print("Processing module \(definition.name)…")

    // MARK: TV Generation Mode Selection

    var etvSetVectors: [TestVector] = []
    var etvSetInputs: [Port] = []

    if let tvSetTest = externalTVSet.value {
        if !fileManager.fileExists(atPath: tvSetTest) {
            Stderr.print("TVs JSON file '\(tvSetTest)' not found.")
            return EX_NOINPUT
        }
        do {
            if tvSetTest.hasSuffix(".json") {
                (etvSetVectors, etvSetInputs) = try TVSet.readFromJson(file: tvSetTest)
            } else {
                (etvSetVectors, etvSetInputs) = try TVSet.readFromText(file: tvSetTest)
            }
        } catch {
            cli.printUsage()
            return EX_USAGE
        }
        print("Read \(etvSetVectors.count) externally-generated vectors to verify.")
    }

    if let tvGenerator = tvGen.value, ETVGFactory.validNames.contains(tvGenerator) {
        let etvgen = ETVGFactory.get(name: tvGenerator)!
        let benchUnwrapped = bench.value! // Program exits if tvGen.value isn't nil and bench.value is or vice versa

        if !fileManager.fileExists(atPath: benchUnwrapped) {
            Stderr.print("Bench file '\(benchUnwrapped)' not found.")
            return EX_NOINPUT
        }
        (etvSetVectors, etvSetInputs) = etvgen.generate(file: benchUnwrapped, module: "\(definition.name)")

        if etvSetVectors.count == 0 {
            Stderr.print("Bench netlist appears invalid (no vectors generated). Are you sure there are no floating nets/outputs?")
            return EX_DATAERR
        } else {
            print("Generated \(etvSetVectors.count) test vectors using external utilties to verify.")
        }
    }

    let tvMinimumCoverage = Float(tvMinimumCoverageInt) / 100.0
    let finalTvCeiling = Int(
        ceiling.value ?? (
            etvSetVectors.count == 0 ?
                defaultCeiling :
                String(etvSetVectors.count)
        )
    )!

    do {
        let (ports, inputs, outputs) = try Port.extract(from: definition)

        if inputs.count == 0 {
            print("Module has no inputs.")
            return EX_OK
        }
        if outputs.count == 0 {
            print("Module has no outputs.")
            return EX_OK
        }

        // MARK: Discover fault points

        var faultPoints: Set<String> = []
        var gateCount = 0
        var inputsMinusIgnored: [Port] = []
        if etvSetVectors.count == 0 {
            inputsMinusIgnored = inputs.filter {
                !ignoredInputs.contains($0.name)
            }
        } else {
            etvSetInputs.sort { $0.ordinal < $1.ordinal }
            inputsMinusIgnored = etvSetInputs.filter {
                !ignoredInputs.contains($0.name)
            }
        }

        for (_, port) in ports {
            if ignoredInputs.contains(port.name) {
                continue
            }
            if port.width == 1 {
                faultPoints.insert(port.name)
            } else {
                let minimum = min(port.from, port.to)
                let maximum = max(port.from, port.to)
                for i in minimum ... maximum {
                    faultPoints.insert("\(port.name) [\(i)]")
                }
            }
        }

        var warnAboutDFF = false

        for itemDeclaration in definition.items {
            let type = Python.type(itemDeclaration).__name__

            // Process gates
            if type == "InstanceList" {
                gateCount += 1
                let instance = itemDeclaration.instances[0]
                if String(describing: instance.module).starts(with: "DFF") {
                    warnAboutDFF = true
                }
                for hook in instance.portlist {
                    faultPoints.insert("\(instance.name).\(hook.portname)")
                }
            }
        }

        if warnAboutDFF {
            print("Warning: D-flipflops were found in this netlist. Are you sure you ran it through 'fault cut'?")
        }

        print("Found \(faultPoints.count) fault sites in \(gateCount) gates and \(ports.count) ports.")

        // MARK: Load Initial Set

        var initialTVInfo: TVInfo? = nil
        if let startingTVSet = startingTVSetOpt.value {
            let loadedInitialTVInfo = try TVInfo.fromJSON(file: startingTVSet)
            print("Loaded \(loadedInitialTVInfo.coverageList.count) initial test vectors.")
            initialTVInfo = loadedInitialTVInfo
        }

        // MARK: Simulation

        let startTime = CFAbsoluteTimeGetCurrent()

        let models = [cells] + Array(includeFiles)

        print("Performing simulations…")
        let result = try Simulator.simulate(
            for: faultPoints,
            in: args[0],
            module: "\(definition.name)",
            with: models,
            ports: ports,
            inputs: inputsMinusIgnored,
            ignoring: ignoredInputs,
            behavior: behavior,
            outputs: outputs,
            initialVectorCount: tvAttempts,
            incrementingBy: tvIncrement,
            minimumCoverage: tvMinimumCoverage,
            ceiling: finalTvCeiling,
            randomGenerator: randomGenerator,
            initialTVInfo: initialTVInfo,
            externalTestVectors: etvSetVectors,
            sampleRun: sampleRun.value,
            clock: clock.value,
            defines: defines,
            using: iverilogExecutable,
            with: vvpExecutable
        )

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time elapsed: \(String(format: "%.2f", timeElapsed))s.")

        print("Simulations concluded: Coverage \(result.coverageMeta.ratio * 100)%")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let tvInfo = TVInfo(
            inputs: inputsMinusIgnored,
            outputs: outputs,
            coverageList: result.coverageList
        )

        let data = try encoder.encode(tvInfo)

        let svfString = try SerialVectorCreator.create(tvInfo: tvInfo)

        guard let string = String(data: data, encoding: .utf8)
        else {
            throw "Could not create utf8 string."
        }
        try File.open(jsonOutput, mode: .write) {
            try $0.print(string)
        }

        try File.open(svfOutput, mode: .write) {
            try $0.print(svfString)
        }

        if let faultPointOutput = faultPointFilePath.value {
            try File.open(faultPointOutput, mode: .write) {
                try $0.write(string: YAMLEncoder().encode(faultPoints.sorted()))
            }
        }

        if let coverageMetaFilePath = coverageMetaFilePath.value {
            try File.open(coverageMetaFilePath, mode: .write) {
                try $0.write(string: YAMLEncoder().encode(result.coverageMeta))
            }
        }

    } catch {
        Stderr.print("Internal error: \(error)")
        return EX_SOFTWARE
    }

    return EX_OK
}

var arguments = Swift.CommandLine.arguments
if arguments.count >= 2, let subcommand = subcommands[arguments[1]] {
    arguments[0] = "\(arguments[0]) \(arguments[1])"
    arguments.remove(at: 1)
    exit(subcommand.func(arguments))
} else {
    exit(main(arguments: arguments))
}
