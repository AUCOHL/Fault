import Foundation
import CommandLineKit
import PythonKit
import Defile

func scanChainCreate(arguments: [String]) -> Int32 {
    let env = ProcessInfo.processInfo.environment
    let defaultLiberty = env["FAULT_INSTALL_PATH"] != nil

    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints this message and exits.")
    cli.addOptions(help)

    let filePath = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Path to the output file. (Default: input + .chained.v)")
    cli.addOptions(filePath)

    let liberty = StringOption(shortFlag: "l", longFlag: "liberty", required: !defaultLiberty, helpMessage: "Liberty file. \(defaultLiberty ? "(Default: osu035)" : "(Required.)")")
    cli.addOptions(liberty)

    let defaultSin = "Sin"
    let sin = StringOption(longFlag: "sin", helpMessage: "Name of shift data in port. (Default: \"\(defaultSin)\")")
    cli.addOptions(sin)

    let defaultSout = "Sout"
    let sout = StringOption(longFlag: "sout", helpMessage: "Name of shift data out port. (Default: \"\(defaultSout)\")")
    cli.addOptions(sout)

    let defaultShift = "Shift"
    let shift = StringOption(longFlag: "shift", helpMessage: "Name of shift enable port. (Default: \"\(defaultShift)\")")
    cli.addOptions(shift)

    do {
        try cli.parse()
    } catch {
        cli.printUsage()
        return EX_USAGE
    }

    if help.value {
        cli.printUsage()
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        cli.printUsage()
        return EX_USAGE
    }

    let file = args[0]
    let output = filePath.value ?? "\(file).chained.v"
    let intermediate = output + ".intermediate.v"

    let libertyFile = defaultLiberty ?
        liberty.value ??
        "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_muxonly.lib" :
        liberty.value!


    // MARK: Importing Python and Pyverilog
    let sys = Python.import("sys")
    sys.path.append(FileManager().currentDirectoryPath + "/Submodules/Pyverilog")

    if let installPath = env["FAULT_INSTALL_PATH"] {
        sys.path.append(installPath + "/FaultInstall/Pyverilog")
    }

    let pyverilogVersion = Python.import("pyverilog.utils.version")
    print("Using Pyverilog v\(pyverilogVersion.VERSION)")

    let parse = Python.import("pyverilog.vparser.parser").parse

    let Node = Python.import("pyverilog.vparser.ast")

    let Generator = Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()
    
    // MARK: Parse
    let ast = parse([args[0]])[0]
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

    // MARK: Register Chain Serialization

    let testingName = shift.value ?? defaultShift
    let testingIdentifier = Node.Identifier(testingName)
    let inputName = sin.value ?? defaultSin
    let inputIdentifier = Node.Identifier(inputName)
    let outputName = sout.value ?? defaultSout
    let outputIdentifier = Node.Identifier(outputName)

    var previousOutput = inputIdentifier

    let ports = Python.list(definition.portlist.ports)
    ports.append(Node.Port(testingName, Python.None, Python.None))
    ports.append(Node.Port(inputName, Python.None, Python.None))
    ports.append(Node.Port(outputName, Python.None, Python.None))
    definition.portlist.ports = Python.tuple(ports)

    var counter = 0

    for itemDeclaration in definition.items {
        let type = Python.type(itemDeclaration).__name__

        // Process gates
        if type == "InstanceList" {
            let instance = itemDeclaration.instances[0]
            if "\(instance.module)".starts(with: "DFF") {
                counter += 1
                for hook in instance.portlist {
                    if hook.portname == "D" {
                        let ternary = Node.Cond(testingIdentifier, previousOutput, hook.argname)
                        hook.argname = ternary
                    }
                    if hook.portname == "Q" {
                        previousOutput = hook.argname
                    }
                }
            }
        }
    }

    let statements = Python.list()
    statements.append(Node.Input(inputName))
    statements.append(Node.Output(outputName))
    statements.append(Node.Input(testingName))
    statements.extend(Python.list(definition.items))

    let finalAssignment = Node.Assign(
        Node.Lvalue(outputIdentifier),
        Node.Rvalue(previousOutput)
    )
    statements.append(finalAssignment)
    definition.items = Python.tuple(statements)

    let metadata = Metadata(dffCount: counter, testEnableIdentifier: testingName, testInputIdentifier: inputName, testOutputIdentifier: outputName)
    guard let metadataString = metadata.toJSON() else {
        fputs("Could not generate metadata string.", stderr)
        return EX_SOFTWARE
    }
    
    do {
        try File.open(intermediate, mode: .write) {
            try $0.print(Generator.visit(ast))
        }

        let script = Synthesis.script(for: "\(definition.name)", in: intermediate, checkHierarchy: false, liberty: libertyFile, output: intermediate, optimize: false)

        let result = "echo '\(script)' | yosys".sh()

        if result != EX_OK {
            fputs("A yosys error has occurred.\n", stderr)
            return Int32(result)
        }

        try File.open(intermediate, mode: .read) { intermediate in
            try File.open(output, mode: .write) {
                try $0.print(String.boilerplate)
                try $0.print("/* FAULT METADATA: '\(metadataString)' */")
                try $0.print(intermediate.string!)
            }
        }
    } catch {
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }

    return EX_OK
}