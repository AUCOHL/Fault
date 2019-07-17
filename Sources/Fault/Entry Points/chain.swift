import Foundation
import CommandLineKit
import PythonKit
import Defile

func scanChainCreate(arguments: [String]) -> Int32 {
    let env = ProcessInfo.processInfo.environment
    let defaultLiberty = env["FAULT_INSTALL_PATH"] != nil

    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(
        shortFlag: "h",
        longFlag: "help",
        helpMessage: "Prints this message and exits."
    )
    cli.addOptions(help)

    let filePath = StringOption(
        shortFlag: "o",
        longFlag: "output",
        helpMessage: "Path to the output file. (Default: input + .chained.v)"
    )
    cli.addOptions(filePath)

    let liberty = StringOption(
        shortFlag: "l",
        longFlag: "liberty",
        required: !defaultLiberty,
        helpMessage:
            "Liberty file. \(defaultLiberty ? "(Default: osu035)" : "(Required.)")"
    )
    cli.addOptions(liberty)

    var names: [String: (default: String, option: StringOption)] = [:]

    for (name, value) in [
        ("sin", "serial data in"),
        ("sout", "serial data out"),
        ("shift", "serial shifting enable"),
        ("rstBar", "JTAG register reset"),
        ("clockBR", "JTAG boundary shift register clock"),
        ("updateBR", "JTAG boundary update register clock"),
        ("modeControl", "JTAG mode input")
    ] {
        let option = StringOption(
            longFlag: name,
            helpMessage: "Name for \(value) signal. (Default: \(name).)"
        )
        cli.addOptions(option)
        names[name] = (default: name, option: option)
    }

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
    let bsrLocation = output + ".bsr.v"

    let libertyFile = defaultLiberty ?
        liberty.value ??
        "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_muxonly.lib" :
        liberty.value!


    // MARK: Importing Python and Pyverilog
    let sys = Python.import("sys")
    sys.path.append(
        FileManager().currentDirectoryPath + "/Submodules/Pyverilog"
    )

    if let installPath = env["FAULT_INSTALL_PATH"] {
        sys.path.append(installPath + "/FaultInstall/Pyverilog")
    }

    let pyverilogVersion = Python.import("pyverilog.utils.version")
    print("Using Pyverilog v\(pyverilogVersion.VERSION)")

    let parse = Python.import("pyverilog.vparser.parser").parse

    let Node = Python.import("pyverilog.vparser.ast")

    let Generator =
        Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()
    
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

    let definitionName = String(describing: definition.name)
    let definitionIdentifer = Node.Identifier(definitionName)
    let alteredName = "__UNIT__UNDER__FINANGLING__"
    let alteredIdentifier = Node.Identifier(alteredName)

    do {
        let (_, inputs, outputs) = try Port.extract(from: definition)

        // MARK: Register chaining original module
        let testingName = names["shift"]!.option.value ?? names["shift"]!.default
        let testingIdentifier = Node.Identifier(testingName)
        let inputName = names["sin"]!.option.value ?? names["sin"]!.default
        let inputIdentifier = Node.Identifier(inputName)
        let outputName = names["sout"]!.option.value ?? names["sout"]!.default
        let outputIdentifier = Node.Identifier(outputName)

        let internalCount: Int = {
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
                    if String(describing: instance.module).starts(with: "DFF") {
                        counter += 1
                        for hook in instance.portlist {
                            if hook.portname == "D" {
                                let ternary = Node.Cond(
                                    testingIdentifier,
                                    previousOutput,
                                    hook.argname
                                )
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
            definition.name = Python.str(alteredName)

            return counter
        }()

        // MARK: New model
        let boundaryCount: Int = try {
            let ports = Python.list(definition.portlist.ports)
            let rstBarName = names["rstBar"]!.option.value
                ?? names["rstBar"]!.default
            let rstBarIdentifier = Node.Identifier(rstBarName)
            let clockBRName = names["clockBR"]!.option.value
                ?? names["clockBR"]!.default
            let clockBRIdentifier = Node.Identifier(clockBRName)
            let updateBRName = names["updateBR"]!.option.value
                ?? names["updateBR"]!.default
            let updateBRIdentifier = Node.Identifier(updateBRName)
            let modeControlName = names["modeControl"]!.option.value
                ?? names["modeControl"]!.default
            let modeControlIdentifier = Node.Identifier(modeControlName)

            ports.append(Node.Port(rstBarName, Python.None, Python.None))
            ports.append(Node.Port(clockBRName, Python.None, Python.None))
            ports.append(Node.Port(updateBRName, Python.None, Python.None))
            ports.append(Node.Port(modeControlName, Python.None, Python.None))

            var statements: [PythonObject] = []
            statements.append(Node.Input(inputName))
            statements.append(Node.Output(outputName))
            statements.append(Node.Input(testingName))
            statements.append(Node.Input(rstBarName))
            statements.append(Node.Input(clockBRName))
            statements.append(Node.Input(updateBRName))
            statements.append(Node.Input(modeControlName))

            let portArguments = Python.list()
            let bsrCreator = BoundaryScanRegisterCreator(
                name: "BoundaryScanRegister",
                rstBar: rstBarName,
                shiftBR: testingName,
                clockBR: clockBRName,
                updateBR: updateBRName,
                modeControl: modeControlName,
                using: Node
            )

            var counter = 0
            
            let initialAssignment = Node.Assign(
                Node.Lvalue(Node.Identifier(inputName.uniqueName(0))),
                Node.Rvalue(inputIdentifier)
            )
            statements.append(initialAssignment)

            for input in inputs {
                let inputStatement = Node.Input(input.name)
                let doutName = String(describing: input.name) + "__dout"
                let doutStatement = Node.Wire(doutName)
                if input.width > 1 {
                    let width = Node.Width(
                        Node.Constant(input.from),
                        Node.Constant(input.to)
                    )
                    inputStatement.width = width
                    doutStatement.width = width
                }
                statements.append(inputStatement)
                statements.append(doutStatement)

                portArguments.append(Node.PortArg(
                    input.name,
                    Node.Identifier(doutName)
                ))

                let minimum = min(input.from, input.to)
                let maximum = max(input.from, input.to)

                for i in (minimum)...(maximum) {
                    statements.append(
                        bsrCreator.create(
                            ordinal: i,
                            din: input.name,
                            dout: doutName,
                            sin: inputName.uniqueName(counter),
                            sout: inputName.uniqueName(counter + 1)
                        )
                    )
                    counter += 1
                }
            }

            portArguments.append(Node.PortArg(
                inputName,
                Node.Identifier(inputName.uniqueName(counter))
            ))

            counter += 1 // as a skip

            portArguments.append(Node.PortArg(
                outputName,
                Node.Identifier(inputName.uniqueName(counter))
            ))

            let submoduleInstance = Node.Instance(
                alteredName,
                "__uuf__",
                Python.tuple(portArguments),
                Python.tuple()
            )

            statements.append(Node.InstanceList(
                alteredName,
                Python.tuple(),
                Python.tuple([submoduleInstance])
            ))

            for output in outputs {
                let outputStatement = Node.Output(output.name)
                let dinName = String(describing: output.name) + "_din"
                let dinStatement = Node.Wire(dinName)
                if output.width > 1 {
                    let width = Node.Width(
                        Node.Constant(output.from),
                        Node.Constant(output.to)
                    )
                    outputStatement.width = width
                    dinStatement.width = width
                }
                statements.append(outputStatement)
                statements.append(dinStatement)

                portArguments.append(Node.PortArg(
                    output.name,
                    Node.Identifier(dinName)
                ))
                
                let minimum = min(output.from, output.to)
                let maximum = max(output.from, output.to)

                for i in (minimum)...(maximum) {
                    statements.append(
                        bsrCreator.create(
                            ordinal: i,
                            din: dinName,
                            dout: output.name,
                            sin:  inputName.uniqueName(counter),
                            sout: inputName.uniqueName(counter + 1)
                        )
                    )
                    counter += 1
                }
            }

            let finalAssignment = Node.Assign(
                Node.Lvalue(outputIdentifier),
                Node.Rvalue(Node.Identifier(inputName.uniqueName(counter)))
            )
            statements.append(finalAssignment)

            var wireDeclarations: [PythonObject] = []
            for i in 0...counter {
                wireDeclarations.append(Node.Wire(inputName.uniqueName(i)))
            }

            let supermodel = Node.ModuleDef(
                definitionName,
                Python.None,
                Node.Portlist(Python.tuple(ports)),
                Python.tuple(wireDeclarations + statements)
            )

            try File.open(bsrLocation, mode: .write) {
                try $0.print(bsrCreator.definition)
            }

            let boundaryScanRegister =
                parse([bsrLocation])[0][dynamicMember: "description"].definitions[0]
            
            let definitions = Python.list(description.definitions)
            definitions.append(boundaryScanRegister)
            definitions.append(supermodel)
            description.definitions = Python.tuple(definitions)

            return counter - 1 // Accounting for skip
        }()

        let metadata = Metadata(
            dffCount: internalCount + boundaryCount,
            testEnableIdentifier: testingName, 
            testInputIdentifier: inputName,
            testOutputIdentifier: outputName
        )
        
        guard let metadataString = metadata.toJSON() else {
            fputs("Could not generate metadata string.", stderr)
            return EX_SOFTWARE
        }
    
        try File.open(intermediate, mode: .write) {
            try $0.print(Generator.visit(ast))
        }

        let script = Synthesis.script(
            for: definitionName,
            in: intermediate,
            checkHierarchy: false,
            liberty: libertyFile,
            output: output
        )

        let result = "echo '\(script)' | yosys".sh()

        if result != EX_OK {
            fputs("A yosys error has occurred.\n", stderr)
            return Int32(result)
        }

        guard let content = File.read(output) else {
            throw "Could not re-read created file."
        }

        try File.open(output, mode: .write) {
            try $0.print(String.boilerplate)
            try $0.print("/* FAULT METADATA: '\(metadataString)' */")
            try $0.print(content)
        }
    } catch {
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }

    return EX_OK
}