import Foundation
import PythonKit
import CommandLineKit

// MARK: CommandLine Processing
let cli = CommandLineKit.CommandLine()

let tvAttemptsDefault = "20"

let filePath = StringOption(shortFlag: "o", longFlag: "outputFile", helpMessage: "Path to the JSON output fil. (Default: stdout.)")
let topModule = StringOption(shortFlag: "t", longFlag: "top", helpMessage: "Module to be processed. (Default: first module found.)")
let netlist = StringOption(shortFlag: "c", longFlag: "cellSimulationFile", required: true, helpMessage: ".v file describing the cells (Required.)")
let testVectorAttempts = StringOption(shortFlag: "a", longFlag: "attempts", helpMessage: "Number of attempts to generate a test vector (Default: \(tvAttemptsDefault).)")
let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints a help message.")

cli.addOptions(topModule, netlist, testVectorAttempts, help)

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

print("Processing module \(definition.name)...")

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

func generateTestbench(for module: String, ports: [String: Port], faultPoint: String, stuckAt: Int) -> [String: UInt]? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let date = Date()
    let dateString = dateFormatter.string(from: date)

    var portWires = ""
    var portHooks = ""

    for (name, port) in ports {
        portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.to):\(port.from)] \(name) ;\n"
        portHooks += ".\(name) ( \(name) ) , "
    }

    let folderName = "faultTest\(UInt16.random(in: 0..<UInt16.max))"
    let _ = "mkdir -p \(folderName)".sh()

    var finalVector: [String: UInt]? = nil

    // in loop?
    for _ in 0..<tvAttempts {
        var inputAssignment = ""

        var vector = [String: UInt]()
        for input in inputs {
            let num = UInt.random(in: 0...UInt.max)
            let mask: UInt = (2 << (UInt(input.width) - 1)) - 1
            let trueNum = num & mask
            vector[input.name] = trueNum
            inputAssignment += "        \(input.name) = \(trueNum) ;\n"
        }

        let vcdName = "\(folderName)/dump.vcd";
        let vcdGMName = "\(folderName)/dumpGM.vcd";

        let bench = """
        /*
            Automatically generated by Fault
            Do not modify.
            Generated on: \(dateString)
        */

        `include "\(netlist.value!)"
        `include "\(args[0])"

        module FaultTestbench;

        \(portWires)

            \(module) uut(
                \(portHooks.dropLast(2))
            );
            
            `ifdef FAULT_WITH
            initial force uut.\(faultPoint) = \(stuckAt) ;
            `endif

            initial begin
                $dumpfile("\(vcdName)");
                $dumpvars(0, FaultTestbench);
        \(inputAssignment)
                #100;
                $finish;
            end

        endmodule
        """;

        let tbName = "\(folderName)/tb.sv"
        let tbFile = Python.open(tbName, mode: "w+")
        tbFile.write(bench)
        tbFile.close()

        let aoutName = "\(folderName)/a.out"

        // Test GM
        let iverilogGMResult = "iverilog -Ttyp -o \(aoutName) \(tbName) 2>&1 > /dev/null".sh()
        if iverilogGMResult != EX_OK {
            exit(Int32(iverilogGMResult))
        }
        let vvpGMResult = "vvp \(aoutName) > /dev/null".sh()
        if vvpGMResult != EX_OK {
            exit(Int32(vvpGMResult))
        }

        let _ = "mv '\(vcdName)' '\(vcdGMName)'".sh()

        let iverilogResult = "iverilog -Ttyp -D FAULT_WITH -o \(aoutName) \(tbName) ".sh()
        if iverilogResult != EX_OK {
            exit(Int32(iverilogGMResult))
        }
        let vvpResult = "vvp \(aoutName) > /dev/null".sh()
        if vvpResult != EX_OK {
            exit(Int32(vvpGMResult))
        }

        let difference = "diff \(vcdName) \(vcdGMName) > /dev/null".sh() == 1
        if (difference) {
            finalVector = vector
            break
        } else {
            //print("Vector \(vector) not viable for \(faultPoint) stuck at \(stuckAt)")
        }
    }

    let _ = "rm -rf \(folderName)".sh()

    return finalVector
}

print("Performing simulations...")

var outputDictionary: [String: [String: [String: UInt]?]] = [:] // We need to go deeper

for (i, point) in faultPoints.enumerated() {
    var currentDictionary: [String: [String: UInt]?] = [:]
    currentDictionary["s-a-0"] = generateTestbench(for: "\(definition.name)", ports: ports, faultPoint: point, stuckAt: 0)
    currentDictionary["s-a-1"] = generateTestbench(for: "\(definition.name)", ports: ports, faultPoint: point, stuckAt: 1)
    outputDictionary[point] = currentDictionary
    print("Processed \(i + 1)/\(faultPoints.count)...")
}

extension String: Error {}

do {
    let encoder = JSONEncoder()
    let data = try encoder.encode(outputDictionary)
    guard let string = String(data: data, encoding: .utf8)
    else {
        throw "Could not create utf8 string."
    }
    if let outputName = filePath.value {
        let outputFile = Python.open(outputName, "w+")
        outputFile.write(string)
        outputFile.close()
    } else {
        print(string)
    }
} catch {
    print("Internal error: \(error)")
    exit(EX_SOFTWARE)
}