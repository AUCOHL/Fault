import Foundation
import CommandLineKit
import PythonKit
import Defile
import CoreFoundation

func main(arguments: [String]) -> Int32 {
    // MARK: CommandLine Processing
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let defaultTVCount = "100"
    let defaultTVIncrement = "50"
    let defaultMinimumCoverage = "80"
    let defaultCeiling = "1000"
    let env = ProcessInfo.processInfo.environment

    let version = BoolOption(
        shortFlag: "V",
        longFlag: "version",
        helpMessage: "Prints the current version and exits."
    )
    if env["FAULT_VER"] != nil {
        cli.addOptions(version)
    }

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

    let cellsOption = StringOption(
        shortFlag: "c",
        longFlag: "cellModel",
        helpMessage: ".v file describing the cells (Required.)"
    )
    cli.addOptions(cellsOption)

    let osu035 = BoolOption(
        longFlag: "osu035",
        helpMessage: "Use the Oklahoma State University standard cell library for -c."
    )
    if env["FAULT_INSTALL_PATH"] != nil {
        cli.addOptions(osu035)
    }

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
        helpMessage: "Minimum number of fault sites covered per cent. Set this to 0 to prevent increments. (Default: \(defaultMinimumCoverage).)"
    )
    cli.addOptions(minimumCoverage)

    let ceiling = StringOption(
        longFlag: "ceiling",
        helpMessage: "Ceiling for Test Vector increments: if this number is reached, no more increments will occur regardless the coverage. (Default: \(defaultCeiling).)"
    )
    cli.addOptions(ceiling)

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

    do {
        try cli.parse()
    } catch {
        cli.printUsage()
        return EX_USAGE
    }

    if version.value {
        print("Fault \(env["FAULT_VER"]!). ©Cloud V 2019. All rights reserved.")
        return EX_OK
    }

    if help.value {
        cli.printUsage()
        print("To take a look at synthesis options, try 'fault synth --help'")
        print("To take a look at cutting options, try 'fault cut --help'")
        print("To take a look at scan chain options, try 'fault chain --help'")
        print("To take a look at test vector assembly options, try 'fault asm --help'")
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        cli.printUsage()
        return EX_USAGE
    }

    let fileManager = FileManager()
    let file = args[0]
    if !fileManager.fileExists(atPath: file) {
        fputs("File '\(file)' not found.\n", stderr)
        return EX_NOINPUT
    }

    if let modelTest = cellsOption.value {
        if !fileManager.fileExists(atPath: modelTest) {
            fputs("Cell model file '\(modelTest)' not found.\n", stderr)
            return EX_NOINPUT
        }
        if !modelTest.hasSuffix(".v") && !modelTest.hasSuffix(".sv") {
            fputs(
                "Warning: Cell model file provided does not end with .v or .sv.",
                stderr
            )
        }
    }
    
    let output = filePath.value ?? "\(file).tv.json"

    guard
        let tvAttempts = Int(testVectorCount.value ?? defaultTVCount),
        let tvIncrement = Int(testVectorIncrement.value ?? defaultTVIncrement),
        let tvMinimumCoverageInt = Int(minimumCoverage.value ?? defaultMinimumCoverage),
        let tvCeiling = Int(ceiling.value ?? defaultCeiling)
    else {
        cli.printUsage()
        return EX_USAGE
    }

    let tvMinimumCoverage = Float(tvMinimumCoverageInt) / 100.0

    let ignoredInputs: Set<String>
        = Set<String>(ignored.value?.components(separatedBy: ",") ?? [])
    let behavior
        = Array<Simulator.Behavior>(
            repeating: .holdHigh,
            count: ignoredInputs.count
        )

    var cellsFile = cellsOption.value

    if osu035.value {
        if cellsFile != nil {
            cli.printUsage()
            return EX_USAGE
        }
        cellsFile = env["FAULT_INSTALL_PATH"]! + "/FaultInstall/Tech/osu035/osu035_stdcells.v"
    }

    guard let cells = cellsFile else {
        cli.printUsage()
        return EX_USAGE
    }

    // MARK: Importing Python and Pyverilog
    let sys = Python.import("sys")
    let path = FileManager().currentDirectoryPath + "/Submodules/Pyverilog"
    sys.path.append(path)
    if let installPath = env["FAULT_INSTALL_PATH"] {
        sys.path.append(installPath + "/FaultInstall/Pyverilog")
    }

    let pyverilogVersion = Python.import("pyverilog.utils.version")
    print("Using Pyverilog v\(pyverilogVersion.VERSION).")

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
        fputs("No module found.\n", stderr)
        return EX_DATAERR
    }

    print("Processing module \(definition.name)…")

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

        let inputsMinusIgnored = inputs.filter {
            !ignoredInputs.contains($0.name)
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
                for i in minimum...maximum {
                    faultPoints.insert("\(port.name)[\(i)]")
                }
            }
        }
        
        for itemDeclaration in definition.items {
            let type = Python.type(itemDeclaration).__name__

            // Process gates
            if type == "InstanceList" {
                gateCount += 1
                let instance = itemDeclaration.instances[0]
                for hook in instance.portlist {
                    faultPoints.insert("\(instance.name).\(hook.portname)")
                }
            }
        }

        print("Found \(faultPoints.count) fault sites in \(gateCount) gates and \(ports.count) ports.")
    
        // MARK: Simulation
        let startTime = CFAbsoluteTimeGetCurrent()

        print("Performing simulations…")
        let result = try Simulator.simulate(
            for: faultPoints,
            in: args[0],
            module: "\(definition.name)",
            with: cells,
            ports: ports,
            inputs: inputsMinusIgnored,
            ignoring: ignoredInputs,
            behavior: behavior,
            outputs: outputs,
            initialVectorCount: tvAttempts,
            incrementingBy: tvIncrement,
            minimumCoverage: tvMinimumCoverage,
            ceiling: tvCeiling,
            sampleRun: sampleRun.value
        )

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time elapsed: \(String(format: "%.2f", timeElapsed))s.")

        print("Simulations concluded: Coverage \(result.coverage * 100)%")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(
            TVInfo(
                inputs: inputsMinusIgnored,
                coverageList: result.coverageList
            )
        )

        guard let string = String(data: data, encoding: .utf8)
        else {
            throw "Could not create utf8 string."
        }

        try File.open(output, mode: .write) {
            try $0.print(string)
        }
    } catch {
        fputs("Internal error: \(error)", stderr)
        return EX_SOFTWARE
    }

    return EX_OK
}

var arguments = Swift.CommandLine.arguments
if Swift.CommandLine.arguments.count >= 2 && Swift.CommandLine.arguments[1] == "synth" {
    arguments[0] = "\(arguments[0]) \(arguments[1])"
    arguments.remove(at: 1)
    exit(synth(arguments: arguments))
} else if Swift.CommandLine.arguments.count >= 2 && Swift.CommandLine.arguments[1] == "chain" {
    arguments[0] = "\(arguments[0]) \(arguments[1])"
    arguments.remove(at: 1)
    exit(scanChainCreate(arguments: arguments))
} else if Swift.CommandLine.arguments.count >= 2 && Swift.CommandLine.arguments[1] == "cut" {
    arguments[0] = "\(arguments[0]) \(arguments[1])"
    arguments.remove(at: 1)
    exit(cut(arguments: arguments))
} else if Swift.CommandLine.arguments.count >= 2 && Swift.CommandLine.arguments[1] == "asm" {
    arguments[0] = "\(arguments[0]) \(arguments[1])"
    arguments.remove(at: 1)
    exit(assemble(arguments: arguments))
}  else {
    exit(main(arguments: arguments))
}
