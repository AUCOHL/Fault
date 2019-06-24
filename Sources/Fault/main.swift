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

    let filePath = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Path to the output JSON file. (Default: stdout.)")
    cli.addOptions(filePath)

    let topModule = StringOption(shortFlag: "t", longFlag: "top", helpMessage: "Module to be processed. (Default: first module found.)")
    cli.addOptions(topModule)


    let cellsOption = StringOption(shortFlag: "c", longFlag: "cellSimulationFile", helpMessage: ".v file describing the cells (Required for simulation.)")
    cli.addOptions(cellsOption)

    let osu035 = BoolOption(longFlag: "osu035", helpMessage: "Use the Oklahoma State University standard cell library for -c.")
    if env["FAULT_INSTALL_PATH"] != nil {
        cli.addOptions(osu035)
    }

    let testVectorAttempts = StringOption(shortFlag: "a", longFlag: "attempts", helpMessage: "Number of test vectors generated (Default: \(tvAttemptsDefault).)")
    cli.addOptions(testVectorAttempts)


    let perVector = BoolOption(longFlag: "simulatePerVector", helpMessage: "Default operation mode. Generates a number of test vectors and tests along all fault sites. Cannot be combined with simulatePerFault.")
    cli.addOptions(perVector)

    let perFault = BoolOption(longFlag: "simulatePerFault", helpMessage: "Generates a test vector per fault instead of the other way around. Has greater coverage, but more test vectors. Cannot be combined with simulatePerVector.")
    cli.addOptions(perFault)

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
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        cli.printUsage()
        return EX_USAGE
    }

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

    let mutualExclusivity = (perFault.value ? 1 : 0) + (perVector.value ? 1 : 0)
    if mutualExclusivity > 1 {
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
    print("Using Pyverilog v\(pyverilogVersion.VERSION)")

    let parse = Python.import("pyverilog.vparser.parser").parse

    // MARK: Parsing and Processing
    let parseResult = parse([args[0]])
    print("\(parseResult[1])")
    let ast = parseResult[0]
    let description = ast[dynamicMember: "description"]
    var definitionOptional: PythonObject?

    for definition in description.definitions {
        let type = Python.type(definition).__name__
        if type == "ModuleDef" {
            if let name = topModule.value {
                if name == "\(definition.name)" {
                    definitionOptional = definition
                    break
                }
            } else {
                definitionOptional = definition
                break
            }
        }
    }

    guard let definition = definitionOptional else {
        return EX_DATAERR
    }

    print("Processing module \(definition.name)…")

    var ports: [String: Port] = [:]
    var inputs: [Port] = []
    var outputs: [Port] = []

    for (i, portDeclaration) in definition.portlist.ports.enumerated() {
        let port = Port(name: "\(portDeclaration.name)", at: i)
        ports["\(portDeclaration.name)"] = port
    }

    var faultPoints: Set<String> = []

    for itemDeclaration in definition.items {
        let type = Python.type(itemDeclaration).__name__

        // Process port declarations further
        if type == "Decl" {
            let declaration = itemDeclaration.list[0]
            let declType = Python.type(declaration).__name__
            if declType == "Input" || declType == "Output" {
                guard let port = ports["\(declaration.name)"] else {
                    print("Parse error: Unknown port.")
                    return EX_DATAERR
                }
                if declaration.width != Python.None {
                    port.from = Int("\(declaration.width.msb)")!
                    port.to = Int("\(declaration.width.lsb)")!
                }
                if declType == "Input" {
                    port.polarity = .input
                    inputs.append(port)
                } else {
                    port.polarity = .output
                    outputs.append(port)
                }
                faultPoints.insert("\(declaration.name)")
            }
        }

        // Process gates
        if type == "InstanceList" {
            let instance = itemDeclaration.instances[0]
            for hook in instance.portlist {
                faultPoints.insert("\(instance.name).\(hook.portname)")
            }
        }
    }

    print("Found \(faultPoints.count) fault sites.")

    if inputs.count == 0 {
        print("Module has no inputs.")
        return EX_OK
    }
    if outputs.count == 0 {
        print("Module has no outputs.")
        return EX_OK
    }

    inputs.sort { $0.ordinal < $1.ordinal }
    outputs.sort { $0.ordinal < $1.ordinal }
    
    // MARK: Simulation
    do {

        let startTime = CFAbsoluteTimeGetCurrent()
        let simulator: Simulation = perFault.value ? PerFaultSimulation() : PerVectorSimulation()

        print("Performing simulations…")
        let result = try simulator.simulate(for: faultPoints, in: args[0], module: "\(definition.name)", with: cells, ports: ports, inputs: inputs, outputs: outputs, tvAttempts: tvAttempts, sampleRun: sampleRun.value)

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time elapsed : \(timeElapsed) s.")

        print("Simulations concluded: Coverage \(result.coverage * 100)%")

        if let outputName = filePath.value {
            try File.open(outputName, mode: .write) {
                try $0.print(result.json)
            }
        } else {
            print(result.json)
        }
    } catch {
        print("Internal error: \(error)")
        return EX_SOFTWARE
    }

    return EX_OK
}

var arguments = Swift.CommandLine.arguments
if Swift.CommandLine.arguments.count >= 2 && Swift.CommandLine.arguments[1] == "synth" {
    arguments[0] = "\(arguments[0]) \(arguments[1])"
    arguments.remove(at: 1)
    exit(synth(arguments: arguments))
} else {
    exit(main(arguments: arguments))
}
