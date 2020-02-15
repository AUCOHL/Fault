import Foundation
import CommandLineKit
import PythonKit
import Defile

func scanChainCreate(arguments: [String]) -> Int32 {
    let env = ProcessInfo.processInfo.environment
    let defaultLiberty = env["FAULT_INSTALL_PATH"] != nil
    
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let defaultBoundaryReset = "boundaryScanReset";

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

    let ignored = StringOption(
        shortFlag: "i",
        longFlag: "ignoring",
        helpMessage: "Inputs,to,ignore,separated,by,commas."
    )
    cli.addOptions(ignored)

    let verifyOpt = StringOption(
        shortFlag: "c",
        longFlag: "cellModel",
        helpMessage: "Verify scan chain using given cell model."
    )
    cli.addOptions(verifyOpt)

    let clockOpt = StringOption(
        longFlag: "clock",
        helpMessage: "Clock signal to add to --ignoring and use in simulation."
    )
    cli.addOptions(clockOpt)

    let resetOpt = StringOption(
        longFlag: "reset",
        helpMessage: "Reset signal to add to --ignoring and use in simulation."
    )
    cli.addOptions(resetOpt)

    let resetActiveLow = BoolOption(
        longFlag: "activeLow",
        helpMessage: "Reset signal is active low instead of active high."
    )
    cli.addOptions(resetActiveLow)

    let addJTAG = BoolOption(
        longFlag: "addJTAG",
        helpMessage: "Add jtag port to the chained netlist."
    )
    cli.addOptions(addJTAG)

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
        ("sinBoundary", "boundary scan register serial data in"),
        ("sinInternal", "internal register serial data in"),
        ("soutBoundary", "boundary scan register serial data out"),
        ("soutInternal",  "internal register serial data out"),
        ("shift", "JTAG shift"),
        ("capture", "JTAG capture"),
        ("update", "JTAG update"),
        ("extest", "JTAG extest"),
        ("tck", "JTAG test clock"),
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

    let fileManager = FileManager()
    let file = args[0]
    if !fileManager.fileExists(atPath: file) {
        fputs("File '\(file)' not found.\n", stderr)
        return EX_NOINPUT
    }

    if let libertyTest = liberty.value {
        if !fileManager.fileExists(atPath: libertyTest) {
            fputs("Liberty file '\(libertyTest)' not found.\n", stderr)
            return EX_NOINPUT
        }
        if !libertyTest.hasSuffix(".lib") {
            fputs(
                "Warning: Liberty file provided does not end with .lib.",
                stderr
            )
        }
    }

    if let modelTest = verifyOpt.value {
        if !fileManager.fileExists(atPath: modelTest) {
            fputs("Cell model file '\(modelTest)' not found.\n", stderr)
            return EX_NOINPUT
        }
        if !modelTest.hasSuffix(".v") && !modelTest.hasSuffix(".sv") {
            fputs(
                "Warning: Cell model file provided does not end with .v or .sv.\n",
                stderr
            )
        }
    }

    let output = filePath.value ?? "\(file).chained.v"
    let intermediate = output + ".intermediate.v"
    let bsrLocation = output + ".bsr.v"

    var ignoredInputs: Set<String>
        = Set<String>(ignored.value?.components(separatedBy: ",") ?? [])
    if let clock = clockOpt.value {
        ignoredInputs.insert(clock)
    }
    if let reset = resetOpt.value {
        ignoredInputs.insert(reset)
    }

    let libertyFile = defaultLiberty ?
        liberty.value ??
        "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_muxonly.lib" :
        liberty.value!


    // MARK: Importing Python and Pyverilog
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

    // MARK: Internal signals
    print("Chaining internal flip-flops…")
    let definitionName = String(describing: definition.name)
    let alteredName = "__UNIT__UNDER__FINANGLING__"

    var internalOrder: [ChainRegister] = []

    do {
        let (_, inputs, outputs) = try Port.extract(from: definition)

        let testingName = names["shift"]!.option.value
            ?? names["shift"]!.default
        let testingIdentifier = Node.Identifier(testingName)

        let inputBoundaryName = names["sinBoundary"]!.option.value
            ?? names["sinBoundary"]!.default
        let inputBoundaryIdentifier = Node.Identifier(inputBoundaryName)

        let inputInternalName = names["sinInternal"]!.option.value 
            ?? names["sinInternal"]!.default
        let inputInternalIdentifier = Node.Identifier(inputInternalName)

        let outputBoundaryName = names["soutBoundary"]!.option.value
            ?? names["soutBoundary"]!.default
        let outputBoundaryIdentifier = Node.Identifier(outputBoundaryName)

        let outputInternalName = names["soutInternal"]!.option.value
            ?? names["soutInternal"]!.default
        let outputInternalIdentifier = Node.Identifier(outputInternalName)

        let captureName = names["capture"]!.option.value ?? names["capture"]!.default
        let updateName = names["update"]!.option.value ?? names["update"]!.default
        let extestName = names["extest"]!.option.value ?? names["extest"]!.default
        let tckName = names["tck"]!.option.value ?? names["tck"]!.default
        
        let resetName = resetOpt.value ?? defaultBoundaryReset
        let clockName = clockOpt.value ?? ""
        // MARK: Register chaining original module
        let internalCount: Int = {
            var previousOutput = inputInternalIdentifier

            let ports = Python.list(definition.portlist.ports)
            ports.append(Node.Port(testingName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(inputInternalName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(outputInternalName, Python.None, Python.None, Python.None))
            definition.portlist.ports = Python.tuple(ports)

            var counter = 0

            for itemDeclaration in definition.items {
                let type = Python.type(itemDeclaration).__name__

                // Process gates
                if type == "InstanceList" {
                    let instance = itemDeclaration.instances[0]
                    if String(describing: instance.module).starts(with: "DFF") {
                        counter += 1
                        internalOrder.append(
                            ChainRegister(
                                name: String(describing: instance.name),
                                kind: .dff
                            )
                        )
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
            statements.append(Node.Input(inputInternalName))
            statements.append(Node.Output(outputInternalName))
            statements.append(Node.Input(testingName))

            statements.extend(Python.list(definition.items))

            let finalAssignment = Node.Assign(
                Node.Lvalue(outputInternalIdentifier),
                Node.Rvalue(previousOutput)
            )
            statements.append(finalAssignment)
            definition.items = Python.tuple(statements)
            definition.name = Python.str(alteredName)

            return counter
        }()

        if clockOpt.value == nil {
            if (internalCount > 0){
                fputs("Error: Clock signal name for the internal logic isn't passed.\n", stderr)
                return EX_NOINPUT
            }
        }
        
        // MARK: Chaining boundary registers
        print("Creating and chaining boundary flip-flops…")
        var boundaryOrder: [ChainRegister] = []

        let boundaryCount: Int = try {
            let ports = Python.list(definition.portlist.ports)
            ports.append(Node.Port(inputBoundaryName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(outputBoundaryName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(captureName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(updateName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(extestName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(tckName, Python.None, Python.None, Python.None))

            if resetOpt.value == nil {
                fputs("Warning: Reset signal isn't passed. \n", stderr)
                fputs("Adding the default reset signal to the module ports.\n", stderr)
                ports.append(Node.Port(resetName, Python.None, Python.None, Python.None))
            }
            
            var statements: [PythonObject] = []
            statements.append(Node.Input(inputInternalName))
            statements.append(Node.Output(outputInternalName))
            statements.append(Node.Input(inputBoundaryName))
            statements.append(Node.Output(outputBoundaryName))
            statements.append(Node.Input(resetName))
            statements.append(Node.Input(tckName))            
            statements.append(Node.Input(testingName))
            statements.append(Node.Input(captureName))
            statements.append(Node.Input(updateName))
            statements.append(Node.Input(extestName))


            if let clock = clockOpt.value {
                statements.append(Node.Input(clock))            
            }

            let portArguments = Python.list()
            let bsrCreator = BoundaryScanRegisterCreator(
                name: "BoundaryScanRegister",
                clock: tckName,
                reset: resetName,
                resetActive: resetActiveLow.value ? .low : .high,
                capture: captureName,
                update: updateName,
                shift: testingName,
                extest: extestName,
                using: Node
            )

            var counter = 0
            
            let initialAssignment = Node.Assign(
                Node.Lvalue(Node.Identifier(inputBoundaryName.uniqueName(0))),
                Node.Rvalue(inputBoundaryIdentifier)
            )
            statements.append(initialAssignment)

            for input in inputs {
                let inputStatement = Node.Input(input.name)

                if (input.name != clockName && input.name != resetName){
                    statements.append(inputStatement)
                }
                if ignoredInputs.contains(input.name) {
                    portArguments.append(Node.PortArg(
                        input.name,
                        Node.Identifier(input.name)
                    ))
                    continue
                }
                
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
                            sin: inputBoundaryName.uniqueName(counter),
                            sout: inputBoundaryName.uniqueName(counter + 1),
                            input: true
                        )
                    )
                    counter += 1
                }

                boundaryOrder.append(
                    ChainRegister(
                        name: String(describing: input.name),
                        kind: .input,
                        width: input.width
                    )
                )
            }

            portArguments.append(Node.PortArg(
                testingName,
                testingIdentifier
            ))

            portArguments.append(Node.PortArg(
                inputInternalName,
                Node.Identifier(inputInternalName)
            ))

            portArguments.append(Node.PortArg(
                outputInternalName,
                Node.Identifier(outputInternalName)
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
                            sin:  inputBoundaryName.uniqueName(counter),
                            sout: inputBoundaryName.uniqueName(counter + 1),
                            input: false
                        )
                    )
                    counter += 1
                }

                boundaryOrder.append(
                    ChainRegister(
                        name: String(describing: output.name),
                        kind: .output,
                        width: output.width
                    )
                )
            }

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

            let boundaryAssignment = Node.Assign(
                Node.Lvalue(outputBoundaryIdentifier),
                Node.Rvalue(Node.Identifier(inputBoundaryName.uniqueName(counter)))
            )
            statements.append(boundaryAssignment)

            var wireDeclarations: [PythonObject] = []
            for i in 0...counter {
                wireDeclarations.append(Node.Wire(inputBoundaryName.uniqueName(i)))
            }

            let supermodel = Node.ModuleDef(
                definitionName,
                Python.None,
                Node.Portlist(Python.tuple(ports)),
                Python.tuple(wireDeclarations + statements)
            )

            try File.open(bsrLocation, mode: .write) {
                try $0.print(bsrCreator.inputDefinition)
                try $0.print(bsrCreator.outputDefinition)
            }

            let boundaryScanRegisters =
                parse([bsrLocation])[0][dynamicMember: "description"].definitions
            
            let definitions = Python.list(description.definitions)
            definitions.extend(boundaryScanRegisters)
            definitions.append(supermodel)
            description.definitions = Python.tuple(definitions)

            return counter - 1 // Accounting for skip
        }()

        let metadata = Metadata(
            boundaryCount: boundaryCount,
            internalCount: internalCount,
            boundaryOrder: boundaryOrder,
            internalOrder: internalOrder,
            shift: testingName, 
            sinBoundary: inputBoundaryName,
            sinInternal: inputInternalName,
            soutBoundary: outputBoundaryName,
            soutInternal: outputInternalName
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
            in: [intermediate],
            checkHierarchy: false,
            liberty: libertyFile,
            output: output
        )

        // MARK: Yosys
        print("Resynthesizing with yosys…")
        let result = "echo '\(script)' | '\(yosysExecutable)' > /dev/null".sh()

        if result != EX_OK {
            fputs("A yosys error has occurred.\n", stderr)
            return Int32(result)
        }

        guard let content = File.read(output) else {
            throw "Could not re-read created file."
        }

        try File.open(output, mode: .write) {
            try $0.print(String.boilerplate)
            try $0.print("/* FAULT METADATA: '\(metadataString)' END FAULT METADATA */")
            try $0.print(content)
        }

        // MARK: Verification
        if let model = verifyOpt.value {
            print("Verifying scan chain integrity…")
            let ast = parse([output])[0]
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
            let (ports, inputs, outputs) = try Port.extract(from: definition)

            let verified = try Simulator.simulate(
                verifying: definitionName,
                in: output, 
                with: model,
                ports: ports,
                inputs: inputs,
                outputs: outputs,
                boundaryCount: boundaryCount,
                internalCount: internalCount,
                clock: clockName,
                reset: resetName,
                tck: tckName,
                sinInternal: inputInternalName,
                sinBoundary: inputBoundaryName,
                soutInternal: outputInternalName,
                soutBoundary: outputBoundaryName,
                resetActive: resetActiveLow.value ? .low : .high,
                testing: testingName,
                using: iverilogExecutable,
                with: vvpExecutable
            )
            print("done")
            if (verified) {
                print("Scan chain verified successfully.")
            } else {
                print("Scan chain verification failed.")
                print("・Ensure that clock and reset signals, if they exist are passed as such to the program.")
                if !resetActiveLow.value {
                    print("・Ensure that the reset is active high- pass --activeLow for activeLow.")
                }
                print("・Ensure that there are no other asynchronous resets anywhere in the circuit.")
            }
        }
        print("Done.")
        
        // MARK: Adding JTAG port
        if addJTAG.value {
            var jtagArguments = [
                arguments[0].components(separatedBy: " ")[0],
                "tap",
                "-l", libertyFile,
                "--reset", resetName,
                "--sinInternal", inputInternalName,
                "--soutInternal", outputInternalName,
                "--sinBoundary", inputBoundaryName,
                "--soutBoundary", outputBoundaryName,
                "--shift", testingName,
                "--capture", captureName,
                "--update", updateName,
                "--tck", tckName,
                output
            ]
            jtagArguments[0] = "\(jtagArguments[0]) \(jtagArguments[1])"
            jtagArguments.remove(at: 1)

            if !clockName.isEmpty {
                jtagArguments.append(contentsOf: ["--clock", clockName])
            }
            if let model = verifyOpt.value {
                jtagArguments.append(contentsOf: ["-c", model])
            }
            if  resetActiveLow.value {
                jtagArguments.append("--activeLow")
            }
            exit(JTAGCreate(arguments: jtagArguments))
        }

    } catch {
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }

    return EX_OK
}