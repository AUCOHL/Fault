import Foundation
import PythonKit
import CommandLineKit
import Defile

func main() {
    // MARK: CommandLine Processing
    let cli = CommandLineKit.CommandLine()

    let tvAttemptsDefault = "100"

    let env = ProcessInfo.processInfo.environment

    let version = BoolOption(shortFlag: "V", longFlag: "version", helpMessage: "Prints the current version and exits.")
    let filePath = StringOption(shortFlag: "o", longFlag: "outputFile", helpMessage: "Path to the JSON output file. (Default: stdout.)")
    let topModule = StringOption(shortFlag: "t", longFlag: "top", helpMessage: "Module to be processed. (Default: first module found.)")

    let cellsOption = StringOption(shortFlag: "c", longFlag: "cellSimulationFile", helpMessage: ".v file describing the cells (Required for simulation.)")
    let osu035 = BoolOption(longFlag: "osu035", helpMessage: "Use the Oklahoma State University standard cell library for -c.")

    let testVectorAttempts = StringOption(shortFlag: "a", longFlag: "attempts", helpMessage: "Number of test vectors generated (Default: \(tvAttemptsDefault).)")
    let perFault = BoolOption(longFlag: "perFault", helpMessage: "Generates a test vector per fault instead of the other way around. Has greater coverage, but more test vectors.")
    let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints this message and exits.")
    
    if env["FAULT_VER"] != nil {
        cli.addOptions(version)
    }
    if env["FAULT_INSTALL_PATH"] != nil {
        cli.addOptions(osu035)
    }

    cli.addOptions(filePath, topModule, cellsOption, testVectorAttempts, perFault, help)
    
    do {
        try cli.parse()
    } catch {
        cli.printUsage()
        exit(EX_USAGE)
    }

    if version.value {
        print("Fault \(env["FAULT_VER"]!). ©Cloud V 2019. All rights reserved.")
        exit(0)
    }

    if help.value {
        cli.printUsage()
        exit(0)
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        cli.printUsage()
        exit(EX_USAGE)
    }

    guard let tvAttempts = Int(testVectorAttempts.value ?? tvAttemptsDefault) else {
        cli.printUsage()
        exit(EX_USAGE)
    }

    var cellsFile = cellsOption.value

    if osu035.value {
        if cellsFile != nil {
            cli.printUsage()
            exit(EX_USAGE)
        }
        cellsFile = env["FAULT_INSTALL_PATH"]! + "/FaultInstall/Tech/osu035/osu035_stdcells.v"
    }

    guard let cells = cellsFile else {
        cli.printUsage()
        exit(EX_USAGE)
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
    let ast = parse([args[0]])[0]
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
        exit(EX_DATAERR)
    }

    print("Processing module \(definition.name)…")

    var ports: [String: Port] = [:]

    for portDeclaration in  definition.portlist.ports {
        let port = Port(name: "\(portDeclaration.name)")
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
                    exit(EX_DATAERR)
                }
                if declaration.width != Python.None {
                    port.from = Int("\(declaration.width.msb)")!
                    port.to = Int("\(declaration.width.lsb)")!
                }
                if (declType == "Input") {
                    port.polarity = .input
                } else {
                    port.polarity = .output
                }
            }
        }

        // Process gates
        if type == "InstanceList" {
            let instance = itemDeclaration.instances[0]
            for hook in instance.portlist {
                let name = "\(hook.argname)"
                faultPoints.insert(name)
            }
        }
    }

    print("Found \(faultPoints.count) fault sites.")

    // Separate Inputs and Outputs
    var inputs: [Port] = []
    var outputs: [Port] = []

    for (_, port) in ports {
        if port.polarity == .input {
            inputs.append(port)
        }
        if port.polarity == .output {
            outputs.append(port)
        }
    }

    if (inputs.count == 0) {
        print("Module has no inputs.")
        exit(0)
    }
    if (outputs.count == 0) {
        print("Module has no outputs.")
        exit(0)
    }

    do {
        var simulator: Simulation = PerVectorSimulation()
        if perFault.value {
            print("Using per-fault site simulation.")
            simulator = PerFaultSimulation()
        }

        print("Performing simulations…")
        let result = try simulator.simulate(for: faultPoints, in: args[0], module: "\(definition.name)", with: cells, ports: ports, inputs: inputs, outputs: outputs, tvAttempts: tvAttempts)

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
        exit(EX_SOFTWARE)
    }
    
}

main()