import Foundation
import PythonKit
import CommandLineKit
import Defile

func main() {
    // MARK: CommandLine Processing
    let cli = CommandLineKit.CommandLine()

    let tvAttemptsDefault = "20"

    let filePath = StringOption(shortFlag: "o", longFlag: "outputFile", helpMessage: "Path to the JSON output fil. (Default: stdout.)")
    let topModule = StringOption(shortFlag: "t", longFlag: "top", helpMessage: "Module to be processed. (Default: first module found.)")
    let netlist = StringOption(shortFlag: "c", longFlag: "cellSimulationFile", required: true, helpMessage: ".v file describing the cells (Required.)")
    let testVectorAttempts = StringOption(shortFlag: "a", longFlag: "attempts", helpMessage: "Number of attempts to generate a test vector (Default: \(tvAttemptsDefault).)")
    let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints a help message.")

    cli.addOptions(filePath, topModule, netlist, testVectorAttempts, help)

    do {
        try cli.parse()
    } catch {
        cli.printUsage()
        exit(EX_USAGE)
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

    // MARK: Importing Python and Pyverilog
    let sys = Python.import("sys")
    sys.path.append(FileManager().currentDirectoryPath + "/Submodules/Pyverilog")
    sys.path.append(FileManager().currentDirectoryPath + "/Submodules/pydotlib")

    let version = Python.import("pyverilog.utils.version")
    print("Using Pyverilog v\(version.VERSION)")

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

    var ports = [String: Port]()

    for portDeclaration in  definition.portlist.ports {
        let port = Port(name: "\(portDeclaration.name)")
        ports["\(portDeclaration.name)"] = port
    }

    var faultPoints = Set<String>()

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

    print("Found \(faultPoints.count) fault points.")

    // Separate Inputs and Outputs
    var inputs = [Port]()
    var outputs = [Port]()

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

    print("Performing simulations (this will take a while)…")

    var promiseDictionary: [String: Future<[String: [String: UInt]?]>] = [:] // We need to go deeper

    for point in faultPoints {
        let module = "\(definition.name)" // Any interaction with Python cannot happen in an asynchronous thread yet.
        let currentDictionary = Future<[String: [String: UInt]?]> {
            var currentDictionary: [String: [String: UInt]?] = [:]
            currentDictionary["s-a-0"] = Simulation.run(for: module, in: args[0], with: netlist.value!, ports: ports, inputs: inputs, at: point, stuckAt: 0, tvAttempts: tvAttempts)
            currentDictionary["s-a-1"] = Simulation.run(for: module, in: args[0], with: netlist.value!, ports: ports, inputs: inputs, at: point, stuckAt: 1, tvAttempts: tvAttempts)
            return currentDictionary
        }
        promiseDictionary[point] = currentDictionary
    }

    var outputDictionary: [String: [String: [String: UInt]?]] = [:]
    for (name, promise) in promiseDictionary {
        outputDictionary[name] = promise.value
    }

    do {
        let encoder = JSONEncoder()
        let data = try encoder.encode(outputDictionary)
        guard let string = String(data: data, encoding: .utf8)
        else {
            throw "Could not create utf8 string."
        } 
        if let outputName = filePath.value {
            File.open(outputName, mode: .write) {
                try! $0.print(string)
            }
        } else {
            print(string)
        }
    } catch {
        print("Internal error: \(error)")
        exit(EX_SOFTWARE)
    }
}

main()