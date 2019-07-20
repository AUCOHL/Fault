import Foundation
import CommandLineKit
import PythonKit
import Defile
import CoreFoundation

func main(arguments: [String]) -> Int32 {
    // MARK: CommandLine Processing
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let tvAttemptsDefault = "100"
    let env = ProcessInfo.processInfo.environment

    let version = BoolOption(shortFlag: "V", longFlag: "version", helpMessage: "Prints the current version and exits.")
    if env["FAULT_VER"] != nil {
        cli.addOptions(version)
    }

    let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints this message and exits.")
    cli.addOptions(help)

    let filePath = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Path to the output JSON file. (Default: input + .tv.json)")
    cli.addOptions(filePath)

    let cellsOption = StringOption(shortFlag: "c", longFlag: "cellModel", helpMessage: ".v file describing the cells (Required for simulation.)")
    cli.addOptions(cellsOption)

    let osu035 = BoolOption(longFlag: "osu035", helpMessage: "Use the Oklahoma State University standard cell library for -c.")
    if env["FAULT_INSTALL_PATH"] != nil {
        cli.addOptions(osu035)
    }

    let testVectorAttempts = StringOption(shortFlag: "a", longFlag: "attempts", helpMessage: "Number of test vectors generated (Default: \(tvAttemptsDefault).)")
    cli.addOptions(testVectorAttempts)

    let sampleRun = BoolOption(longFlag: "sampleRun", helpMessage: "Generate only one testbench for inspection, do not delete it. Has no effect under registerChain.")
    cli.addOptions(sampleRun)

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
        print("To take a look at scan chain options, try 'fault scanc --help'")
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
        fputs("File '\(file)'' not found.", stderr)
        return EX_NOINPUT
    }
    
    let output = filePath.value ?? "\(file).tv.json"

    guard let tvAttempts = Int(testVectorAttempts.value ?? tvAttemptsDefault) else {
        cli.printUsage()
        return EX_USAGE
    }

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
    sys.path.append(FileManager().currentDirectoryPath + "/Submodules/Pyverilog")

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

        for (_, port) in ports {
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
        let result = try Simulator.simulate(for: faultPoints, in: args[0], module: "\(definition.name)", with: cells, ports: ports, inputs: inputs, outputs: outputs, tvAttempts: tvAttempts, sampleRun: sampleRun.value)

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time elapsed: \(String(format: "%.2f", timeElapsed))s.")

        print("Simulations concluded: Coverage \(result.coverage * 100)%")


        try File.open(output, mode: .write) {
            try $0.print(result.json)
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
} else {
    exit(main(arguments: arguments))
}
