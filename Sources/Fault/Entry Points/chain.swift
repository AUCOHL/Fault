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
        required: true,
        helpMessage: "Clock signal to add to --ignoring and use in simulation. (Required.)."
    )
    cli.addOptions(clockOpt)

    let clockInv = StringOption(
        longFlag: "invClock",
        helpMessage: "Inverted clk tree source cell name (Default: none)"
    )
    cli.addOptions(clockInv)

    let resetOpt = StringOption(
        longFlag: "reset",
        required: true,
        helpMessage: "Reset signal to add to --ignoring and use in simulation.  (Required.)"
    )
    cli.addOptions(resetOpt)

    let resetActiveLow = BoolOption(
        longFlag: "activeLow",
        helpMessage: "Reset signal is active low instead of active high."
    )
    cli.addOptions(resetActiveLow)

    let liberty = StringOption(
        shortFlag: "l",
        longFlag: "liberty",
        required: !defaultLiberty,
        helpMessage:
            "Liberty file. \(defaultLiberty ? "(Default: osu035)" : "(Required.)")"
    )
    cli.addOptions(liberty)

    let dffOpt = StringOption(
        shortFlag: "d",
        longFlag: "dff",
        helpMessage: "Flip-flop cell name (Default: DFF)"
    )
    cli.addOptions(dffOpt)

    let isolated = StringOption(
        longFlag: "isolating",
        helpMessage: "Isolated module definitions (.v) (Hard un-scannable blocks). (Default: none)"
    )
    cli.addOptions(isolated)

    var names: [String: (default: String, option: StringOption)] = [:]

    for (name, value) in [
        ("sin", "Scan-chain serial data in"),
        ("sout", "Scan-chain serial data out"),
        ("mode", "Input/Output scan-cell mode"),
        ("shift", "Input/Output scan-cell shift"),
        ("clockDR", "Input/Output scan-cell clock DR"),
        ("update", "Input/Output scan-cell update"),
        ("test", "test mode enable"),
        ("tck", "test clock")
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
    let dffName = dffOpt.value ?? "DFF"

    var ignoredInputs: Set<String>
        = Set<String>(ignored.value?.components(separatedBy: ",").filter {$0 != ""} ?? [])
    let clockName = clockOpt.value!
    let resetName = resetOpt.value!

    ignoredInputs.insert(clockName)
    ignoredInputs.insert(resetName)

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

    var isolatedOptional: PythonObject?
    var isolatedName: String?
    if let file = isolated.value {
        let ast = parse([file])[0]
        let description = ast[dynamicMember: "description"]
        for definition in description.definitions {
            let type = Python.type(definition).__name__
            if type == "ModuleDef" {
                isolatedOptional = definition
                isolatedName = String(describing: definition.name)
                break
            }
        }
    }

    if let _ = isolatedOptional {
    } else {
        if let isolatedFile = isolated.value {
            fputs("No module defintion found in \(isolatedFile)", stderr)
            return EX_DATAERR
        }
    }

    // MARK: Internal signals
    print("Chaining internal flip-flops…")
    let definitionName = String(describing: definition.name)
    let alteredName = "__UNIT__UNDER__FINANGLING__"

    var internalOrder: [ChainRegister] = []

    do {
        let (_, inputs, outputs) = try Port.extract(from: definition)

        let shiftName = names["shift"]!.option.value ?? names["shift"]!.default
        let shiftIdentifier = Node.Identifier(shiftName)
        let inputName = names["sin"]!.option.value ?? names["sin"]!.default
        let inputIdentifier = Node.Identifier(inputName)
        let outputName = names["sout"]!.option.value ?? names["sout"]!.default
        let outputIdentifier = Node.Identifier(outputName)
        let modeName = names["mode"]!.option.value ?? names["mode"]!.default
        let clockDRName = names["clockDR"]!.option.value ?? names["clockDR"]!.default
        let updateName = names["update"]!.option.value ?? names["update"]!.default
        let testName = names["test"]!.option.value ?? names["test"]!.default

        let tckName = names["tck"]!.option.value ?? names["tck"]!.default
        let clkSourceName = "__clk_source__"
        let clkSourceId = Node.Identifier(clkSourceName)

        var invClkSourceName: String?
        var invClkSourceId: PythonObject? 

        // MARK: Register chaining original module
        var previousOutput = inputIdentifier

        let statements = Python.list()
        statements.append(Node.Input(inputName))
        statements.append(Node.Output(outputName))
        statements.append(Node.Input(shiftName))
        statements.append(Node.Input(tckName))
        statements.append(Node.Input(testName))

        statements.extend(Python.list(definition.items))

        let ports = Python.list(definition.portlist.ports)
        ports.append(Node.Port(inputName, Python.None, Python.None, Python.None))
        ports.append(Node.Port(shiftName, Python.None, Python.None, Python.None))
        ports.append(Node.Port(outputName, Python.None, Python.None, Python.None))
        ports.append(Node.Port(tckName, Python.None, Python.None, Python.None))
        ports.append(Node.Port(testName, Python.None, Python.None, Python.None))

        definition.portlist.ports = Python.tuple(ports)
            
        var warn = false
        for itemDeclaration in definition.items {
            let type = Python.type(itemDeclaration).__name__
            // Process gates
            if type == "InstanceList" {
                let instance = itemDeclaration.instances[0]
                let instanceName = String(describing: instance.module)
                if instanceName.starts(with: dffName) {
                    for hook in instance.portlist {
                        if hook.portname == "CLK" {
                            if String(describing: hook.argname) == clockName {
                                hook.argname = clkSourceId
                            }
                            else {
                                warn = true
                            }
                        }
                        if hook.portname == "D" {
                            let ternary = Node.Cond(
                                shiftIdentifier,
                                previousOutput,
                                hook.argname
                            )
                            hook.argname = ternary
                        }

                        if hook.portname == "Q" {
                            previousOutput = hook.argname
                        }
                    }

                    internalOrder.append(
                        ChainRegister(
                            name: String(describing: instance.name),
                            kind: .dff
                        )
                    )

                } else if let name = isolatedName, name == instanceName {
                    // MARK: Isolating hard blocks
                    print("Chaining hard module...")
                    let (_, inputs, _) = try Port.extract(from: isolatedOptional!)
                    let isolatedInputs = inputs.map { $0.name }

                    let scCreator = scanCellCreator(
                        name: "ScanCell",
                        clock: clkSourceName ,
                        shift: shiftName,
                        using: Node
                    )

                    for hook in instance.portlist {
                        let hookType = Python.type(hook.argname).__name__
                        let portName = String(describing: hook.portname)
                        let input = isolatedInputs.contains(portName)

                        if hookType == "Concat" {
                            var list: [PythonObject] = []
                            for (i, element) in  hook.argname.list.enumerated() {
                                let elementName = String(describing: element.name)
                                if ignoredInputs.contains(elementName) {
                                    continue
                                }

                                let outName = "__\(portName)_\(i)__"
                                list.append(Node.Identifier(outName))

                                var out: String, din: String
                                var kind: ChainRegister.Kind
                                if input {
                                    din = elementName
                                    out = outName  
                                    kind = .bypassInput                              
                                } else {
                                    din = outName
                                    out = elementName
                                    kind = .bypassOutput
                                }
                                statements.append(Node.Wire(outName))
                                statements.append(
                                    scCreator.create(
                                        din: din,
                                        sin: "\(previousOutput)",
                                        out: out
                                    )
                                )
                                internalOrder.append(
                                    ChainRegister(
                                        name: instanceName + "_\(portName)_\(i)",  
                                        kind: kind
                                    )
                                ) 
                                previousOutput = Node.Identifier(out)
                            }
                            hook.argname.list = Python.tuple(list)
                        } else {
                            let argName = String(describing: hook.argname)
                            if ignoredInputs.contains(argName) {
                                continue
                            }
                            
                            let outName = "__\(hook.portname)__"
                            hook.argname = Node.Identifier(outName)

                            var din: String, out: String
                            var kind: ChainRegister.Kind
                            if input {
                                din = argName
                                out = outName
                                kind = .bypassInput
                            } else {
                                din = outName
                                out = argName  
                                kind = .bypassOutput                         
                            }
                            statements.append(Node.Wire(outName))
                            statements.append(
                                scCreator.create(
                                    din: din,
                                    sin: String(describing: previousOutput),
                                    out: out
                                )
                            )
                            internalOrder.append(
                                ChainRegister(
                                    name: instanceName + "_\(hook.portname)",
                                    kind: kind
                                )
                            ) 
                            previousOutput = Node.Identifier(out)
                        }
                    }

                    let location = output + ".sc_cell.v"
                    try File.open(location, mode: .write) {
                        try $0.print(scCreator.cellDefinition)
                    }
                    let scanCells =
                        parse([location])[0][dynamicMember: "description"].definitions
                    let definitions = Python.list(description.definitions)

                    definitions.extend(scanCells)
                    description.definitions = Python.tuple(definitions)
                }

                if let invClockName = clockInv.value, instanceName == invClockName  { 
                    for hook in instance.portlist {
                        if String(describing: hook.argname) == clockName {
                            invClkSourceName = "__clk_source_n__"
                            invClkSourceId = Node.Identifier(invClkSourceName)
                            hook.argname = invClkSourceId!
                        }
                    }
                }   
            }

        }

        if warn {
            print("[Warning]: Detected flip-flops with clock different from \(clockName).")
        }

        let finalAssignment = Node.Assign(
            Node.Lvalue(outputIdentifier),
            Node.Rvalue(previousOutput)
        )
        statements.append(finalAssignment)

        let clockCond = Node.Cond(
            Node.Identifier(testName),
            Node.Identifier(tckName),
            Node.Identifier(clockName)
        )
        let clkSourceAssignment = Node.Assign(
            Node.Lvalue(clkSourceId),
            Node.Rvalue(clockCond)
        )
        statements.append(Node.Wire(clkSourceName))
        statements.append(clkSourceAssignment)
        
        if let invClkName = invClkSourceName, let invClkId = invClkSourceId {
            let invClockCond = Node.Cond(
                Node.Identifier(testName),
                Node.Unot(Node.Identifier(tckName)),
                Node.Identifier(clockName)
            )
    
            let invClockAssignment = Node.Assign(
                Node.Lvalue(invClkId),
                Node.Rvalue(invClockCond)
            )
            statements.append(Node.Wire(invClkName))
            statements.append(invClockAssignment)
        }

        definition.items = Python.tuple(statements)
        definition.name = Python.str(alteredName)
        
        print(internalOrder.count)

        // MARK: Chaining boundary registers
        print("Creating and chaining boundary flip-flops…")
        var order: [ChainRegister] = []
        let boundaryCount: Int = try {
            let ports = Python.list(definition.portlist.ports)
            ports.append(Node.Port(clockDRName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(updateName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(modeName, Python.None, Python.None, Python.None))

            var statements: [PythonObject] = []
            statements.append(Node.Input(inputName))
            statements.append(Node.Output(outputName))
            statements.append(Node.Input(resetName))
            statements.append(Node.Input(shiftName))
            statements.append(Node.Input(tckName))
            statements.append(Node.Input(testName))
            statements.append(Node.Input(clockDRName))
            statements.append(Node.Input(updateName))
            statements.append(Node.Input(modeName))

            if let clock = clockOpt.value {
                statements.append(Node.Input(clock))            
            }

            let portArguments = Python.list()
            let bsrCreator = BoundaryScanRegisterCreator(
                name: "BoundaryScanRegister",
                clock: tckName,
                reset: resetName,
                resetActive: resetActiveLow.value ? .low : .high,
                clockDR: clockDRName,
                update: updateName,
                shift: shiftName,
                mode: modeName,
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
                            sin: inputName.uniqueName(counter),
                            sout: inputName.uniqueName(counter + 1),
                            input: true
                        )
                    )
                    counter += 1
                }

                order.append(
                    ChainRegister(
                        name: String(describing: input.name),
                        kind: .input,
                        width: input.width
                    )
                )
            }

            portArguments.append(Node.PortArg(
                shiftName,
                shiftIdentifier
            ))
            portArguments.append(Node.PortArg(
                tckName,
                Node.Identifier(tckName)
            ))
            portArguments.append(Node.PortArg(
                testName,
                Node.Identifier(testName)
            ))

            portArguments.append(Node.PortArg(
                inputName,
                Node.Identifier(inputName.uniqueName(counter))
            ))
            
            counter += 1 // as a skip
            order += internalOrder

            portArguments.append(Node.PortArg(
                outputName,
                Node.Identifier(inputName.uniqueName(counter))
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
                            sout: inputName.uniqueName(counter + 1),
                            input: false
                        )
                    )
                    counter += 1
                }

                order.append(
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
                Node.Lvalue(outputIdentifier),
                Node.Rvalue(Node.Identifier(inputName.uniqueName(counter)))
            )
            statements.append(boundaryAssignment)

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

        print(boundaryCount)

        let metadata = ChainMetadata(
            boundaryCount: boundaryCount,
            internalCount: internalOrder.count,
            order: order,
            shift: shiftName, 
            sin: inputName,
            sout: outputName
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
                isolating: isolated.value,
                with: model,
                ports: ports,
                inputs: inputs,
                outputs: outputs,
                chainLength: boundaryCount +  internalOrder.count,
                clock: clockName,
                tck: tckName,
                reset: resetName,
                sin: inputName,
                sout: outputName,
                resetActive: resetActiveLow.value ? .low : .high,
                shift: shiftName,
                test: testName,
                clockDR: clockDRName,
                update: updateName,
                mode: modeName,
                output: output + ".tb.sv",
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
                if internalOrder.count == 0 {
                    print("・Ensure that D flip-flop cell name starts with \(dffName).")
                }
                print("・Ensure that there are no other asynchronous resets anywhere in the circuit.")
            }
        }
        print("Done.")
    
    } catch {
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }
    return EX_OK
}