import Foundation
import CommandLineKit
import PythonKit
import Defile

func cut(arguments: [String]) -> Int32 {
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(
        shortFlag: "h",
        longFlag: "help",
        helpMessage: "Prints this message and exits."
    )
    cli.addOptions(help)

    let dffOpt = StringOption(
        shortFlag: "d",
        longFlag: "dff",
        helpMessage: "Flip-flop cell name (Default: DFF)."
    )
    cli.addOptions(dffOpt)

    let clock = StringOption(
        longFlag: "clock",
        helpMessage: "clock name for the cut flip-flops. (Default: all flip-flops are cut)"
    )
    cli.addOptions(clock)

    let filePath = StringOption(
        shortFlag: "o",
        longFlag: "output",
        helpMessage: "Path to the output file. (Default: input + .chained.v)"
    )
    cli.addOptions(filePath)

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

    let fileManager = FileManager()
    let file = args[0]
    if !fileManager.fileExists(atPath: file) {
        fputs("File '\(file)' not found.\n", stderr)
        return EX_NOINPUT
    }
    let dffName = dffOpt.value ?? "DFF"
    let output = filePath.value ?? "\(file).cut.v"

    // MARK: Importing Python and Pyverilog
    
    let parse = Python.import("pyverilog.vparser.parser").parse

    let Node = Python.import("pyverilog.vparser.ast")

    let Generator =
        Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()

    // MARK: Parse
    let ast = parse([file])[0]
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
        exit(EX_DATAERR)
    }

    let ports = Python.list(definition.portlist.ports)
    var declarations: [PythonObject] = []
    var items: [PythonObject] = []

    for item in definition.items {
        var include = true

        let type = Python.type(item).__name__

        // Process gates
        if type == "InstanceList" {
            let instance = item.instances[0]
            if String(describing: instance.module).starts(with: dffName) {
                let instanceName = String(describing: instance.name)
                let outputName = "\\" + instanceName + ".q"

                let inputIdentifier = Node.Identifier(instanceName)
                let outputIdentifier = Node.Identifier(outputName)

                include = false
                var dArg: PythonObject?
                var qArg: PythonObject?

                for hook in instance.portlist {
                    if hook.portname == "D" {
                        dArg = hook.argname
                    }
                    if hook.portname == "Q" {
                        qArg = hook.argname
                    }
                    if hook.portname == "CLK" {
                        if let clockName = clock.value {
                            include = String(describing: hook.argname) != clockName
                        }
                    }
                }

                if include {
                    items.append(item)
                    print("[Warning]: Not all flip-flops have the same clock \(clock.value!).")
                    print("・Ensure that there is no negedge triggered flip-flops.")
                    continue
                }

                guard let d = dArg, let q = qArg else {
                    fputs(
                        "Cell \(instanceName) missing either a 'D' or 'Q' port."
                        , stderr
                    )
                    return EX_DATAERR
                }

                ports.append(Node.Port(instanceName, Python.None, Python.None, Python.None))
                ports.append(Node.Port(outputName, Python.None, Python.None, Python.None))

                declarations.append(Node.Input(instanceName))
                declarations.append(Node.Output(outputName))

                let inputAssignment = Node.Assign(
                    Node.Lvalue(q),
                    Node.Rvalue(inputIdentifier)
                )
                let outputAssignment = Node.Assign(
                    Node.Lvalue(outputIdentifier),
                    Node.Rvalue(d)
                )

                items.append(inputAssignment)
                items.append(outputAssignment)
            }
        }

        if include {
            items.append(item)
        }
    }

    definition.portlist.ports = ports
    definition.items = Python.tuple(declarations + items)

    do {
        try File.open(output, mode: .write) {
            try $0.print(String.boilerplate)
            try $0.print(Generator.visit(ast))
        }
    } catch {
        fputs("An internal software error has occurred.", stderr)
        return EX_SOFTWARE
    }   
    
    return EX_OK
}