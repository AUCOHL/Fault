import Foundation
import CommandLineKit
import PythonKit
import Defile

enum scanStructure: String {
    case one = "one"
    case multi = "multi" 
}

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

    // one: stitches the boundary scan to FF register 
    // multi: creates at most 3 scan-chains: boundary scan-chain, posedge FF chain, negedge FF chain.
    let scanOpt = EnumOption<scanStructure>(
        longFlag: "scan",
        helpMessage: "Specifies scan-chain strucutre: one, multi. (Default: one) \n"
    )
    cli.addOptions(scanOpt)

    var names: [String: (default: String, option: StringOption)] = [:]

    for (name, value) in [
        ("sin", "boundary scan register serial data in"),
        ("sout", "boundary scan register serial data out"),
        ("mode", "boundary scan cell mode"),
        ("tck", "test clock"),
        ("shift", "JTAG shift"),
        ("clockDR", "BS cell clock DR"),
        ("update", "JTAG update")
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

    let scanStructure = scanOpt.value ?? .one
    var internalOrder: [[ChainRegister]] = [[]]
    var chainPorts: [[String: (name: String, id: PythonObject)]] = []
    var bsPorts: [String: (name: String, id: PythonObject)] = [:]

    do {
        let (_, inputs, outputs) = try Port.extract(from: definition)

        let testingName = names["shift"]!.option.value ?? names["shift"]!.default
        let inputName = names["sin"]!.option.value ?? names["sin"]!.default
        let outputName = names["sout"]!.option.value ?? names["sout"]!.default
        let tckName = names["tck"]!.option.value ?? names["tck"]!.default

        var previousOutput: [PythonObject] =  []
        switch scanStructure {
        case .one: // stitches FFs to bs_chain with ignoring FFs that have different sensitivity list
            let oneChain = [
                "sin": (name: inputName, id: Node.Identifier(inputName)),
                "sout": (name: outputName, id: Node.Identifier(outputName)),
                "shift": (name: testingName, id: Node.Identifier(testingName)),
                "clk": (name: "__clk_source__", id: Node.Identifier("__clk_source__"))
            ]
            chainPorts.append(oneChain)
            previousOutput.append(oneChain["sin"]!.id)
            break
        case .multi: // seperates boundary scan cell for FFs
            for i in 1..<3 {
                let internalPorts = [
                    "sin": (name: "\(inputName)_\(i)", id: Node.Identifier("\(inputName)_\(i)")),
                    "sout": (name: "\(outputName)_\(i)", id: Node.Identifier("\(outputName)_\(i)")),
                    "shift": (name: "\(testingName)_\(i)", id: Node.Identifier("\(testingName)_\(i)")),
                    "clk": (name: "__clk_source_\(i)__", id: Node.Identifier("__clk_source_\(i)__")) 
                ]
                chainPorts.append(internalPorts)
            }
            bsPorts = [
                "sin": (name: "bs_\(inputName)", id: Node.Identifier("bs_\(inputName)")),
                "sout": (name: "bs_\(outputName)", id: Node.Identifier("bs_\(outputName)")),
                "shift": (name: "bs_\(testingName)", id: Node.Identifier("bs_\(testingName)"))
            ]          
            break
        }

        let modeName = names["mode"]!.option.value ?? names["mode"]!.default
        let clockDRName = names["clockDR"]!.option.value ?? names["clockDR"]!.default
        let updateName = names["update"]!.option.value ?? names["update"]!.default
        
        let resetName = resetOpt.value ?? defaultBoundaryReset
        let clockName = clockOpt.value ?? ""

        // MARK: Register chaining original module
        let statements = Python.list()
        statements.append(Node.Input(tckName))

        let ports = Python.list(definition.portlist.ports)
        ports.append(Node.Port(tckName, Python.None, Python.None, Python.None))

        for chain in chainPorts {
            ports.append(Node.Port(chain["sin"]!.name, Python.None, Python.None, Python.None))
            ports.append(Node.Port(chain["shift"]!.name, Python.None, Python.None, Python.None))
            ports.append(Node.Port(chain["sout"]!.name, Python.None, Python.None, Python.None))

            previousOutput.append(chain["sin"]!.id)

            statements.append(Node.Input(chain["sin"]!.name))
            statements.append(Node.Input(chain["shift"]!.name))
            statements.append(Node.Output(chain["sout"]!.name))
        }
        definition.portlist.ports = Python.tuple(ports)
        statements.extend(Python.list(definition.items))

        let partialChain = scanStructure == .one

        for itemDeclaration in definition.items {
            let type = Python.type(itemDeclaration).__name__

            // Process gates
            if type == "InstanceList" {
                let instance = itemDeclaration.instances[0]
                if String(describing: instance.module).starts(with: dffName) {

                    var chainIndex = 0
                    for hook in instance.portlist {
                        if hook.portname == "CLK" {
                            if String(describing: hook.argname) != clockName {
                                if partialChain {
                                    continue
                                }
                                chainIndex = 1
                            }
                            else {
                                chainIndex = 0
                            }
                            hook.argname = chainPorts[chainIndex]["clk"]!.id
                        }

                        if hook.portname == "D" {
                            let ternary = Node.Cond(
                                chainPorts[chainIndex]["shift"]!.id,
                                previousOutput[chainIndex],
                                hook.argname
                            )
                            hook.argname = ternary
                        }
                        if hook.portname == "Q" {
                            previousOutput[chainIndex] = hook.argname
                        }
                    }
                    internalOrder[chainIndex].append(
                        ChainRegister(
                            name: String(describing: instance.name),
                            kind: .dff
                        )
                    ) 
                }
            }
        }

        for i in 0..<chainPorts.count {
            let finalAssignment = Node.Assign(
                Node.Lvalue(chainPorts[i]["sout"]!.id),
                Node.Rvalue(previousOutput[i])
            )
            statements.append(finalAssignment)

            let clockCond = Node.Cond(
                chainPorts[i]["shift"]!.id,
                Node.Identifier(tckName),
                Node.Identifier(clockName)
            )
            let clkSource = Node.Assign(
                Node.Lvalue(chainPorts[i]["clk"]!.id),
                Node.Rvalue(clockCond)
            )
            statements.append(Node.Wire(chainPorts[i]["clk"]!.name))
            statements.append(clkSource)
        }

        definition.items = Python.tuple(statements)
        definition.name = Python.str(alteredName)

        if clockOpt.value == nil {
            if internalOrder[0].count > 0 {
                fputs("[Error]: Clock signal name for the internal logic isn't passed.\n", stderr)
                return EX_NOINPUT
            }
        }

        if internalOrder[0].count == 0 {
            print("[Warning]: detected no internal flip flops triggered by \(clockName).Are you sure that flip-flop cell name starts with \(dffName) ? ")
        }
        if internalOrder.count == 2 {
            if internalOrder[1].count == 0 {
                print("[Warning]: detected flip flops triggered by different clock. Partial scan-chain is created.")
            }
        }

        // MARK: Chaining boundary registers
        print("Creating and chaining boundary flip-flops…")
        var order: [ChainRegister] = []
        let boundaryCount: Int = try {
            let ports = Python.list(definition.portlist.ports)
            ports.append(Node.Port(clockDRName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(updateName, Python.None, Python.None, Python.None))
            ports.append(Node.Port(modeName, Python.None, Python.None, Python.None))

            if resetOpt.value == nil {
                fputs("[Warning]: Reset signal isn't passed. \n", stderr)
                fputs("Adding the default reset signal to the module ports.\n", stderr)
                ports.append(Node.Port(resetName, Python.None, Python.None, Python.None))
            }

            var statements: [PythonObject] = []
            statements.append(Node.Input(resetName))
            statements.append(Node.Input(clockDRName))
            statements.append(Node.Input(updateName))
            statements.append(Node.Input(modeName))
            statements.append(Node.Input(tckName))

            if scanStructure == .multi {
                ports.append(Node.Port(bsPorts["sin"]!.name, Python.None, Python.None, Python.None))
                ports.append(Node.Port(bsPorts["sout"]!.name, Python.None, Python.None, Python.None))
                chainPorts.append(bsPorts)
            }

            for port in chainPorts {
                statements.append(Node.Input(port["sin"]!.name))
                statements.append(Node.Input(port["shift"]!.name))
                statements.append(Node.Output(port["sout"]!.name))
            }

            if let clock = clockOpt.value {
                statements.append(Node.Input(clock))            
            }

            let inputName = chainPorts.last!["sin"]!.name
            let inputIdentifier = chainPorts.last!["sin"]!.id
            let outputIdentifier = chainPorts.last!["sout"]!.id
            let shiftName = chainPorts.last!["shift"]!.name

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

            // MARK: ports for chained module instance
            portArguments.append(Node.PortArg(
                tckName,
                Node.Identifier(tckName)
            ))
            for (i, chain) in chainPorts.enumerated() {
                if i == 2 {
                    break
                }
                portArguments.append(Node.PortArg(
                    chain["sin"]!.name,
                    chain["sin"]!.id
                ))
                portArguments.append(Node.PortArg(
                    chain["shift"]!.name,
                    chain["shift"]!.id
                ))
                portArguments.append(Node.PortArg(
                    chain["sout"]!.name,
                    chain["sout"]!.id
                ))
            }

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

        let metadata = ChainMetadata(
            boundaryCount: boundaryCount,
            internalCount: internalOrder[0].count,
            order: order,
            shift: "shift", 
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
        // if let model = verifyOpt.value {
        //     print("Verifying scan chain integrity…")
        //     let ast = parse([output])[0]
        //     let description = ast[dynamicMember: "description"]
        //     var definitionOptional: PythonObject?
        //     for definition in description.definitions {
        //         let type = Python.type(definition).__name__
        //         if type == "ModuleDef" {
        //             definitionOptional = definition
        //             break
        //         }
        //     }
        //     guard let definition = definitionOptional else {
        //         fputs("No module found.\n", stderr)
        //         return EX_DATAERR
        //     }
        //     let (ports, inputs, outputs) = try Port.extract(from: definition)

        //     let verified = try Simulator.simulate(
        //         verifying: definitionName,
        //         in: output, 
        //         with: model,
        //         ports: ports,
        //         inputs: inputs,
        //         outputs: outputs,
        //         boundaryCount: boundaryCount,
        //         internalCount: internalCount,
        //         clock: clockName,
        //         reset: resetName,
        //         sin: inputName,
        //         sout: outputName,
        //         resetActive: resetActiveLow.value ? .low : .high,
        //         testing: testingName,
        //         clockDR: clockDRName,
        //         update: updateName,
        //         mode: modeName,
        //         output: output + ".tb.sv",
        //         using: iverilogExecutable,
        //         with: vvpExecutable
        //     )
        //     print("done")
        //     if (verified) {
        //         print("Scan chain verified successfully.")
        //     } else {
        //         print("Scan chain verification failed.")
        //         print("・Ensure that clock and reset signals, if they exist are passed as such to the program.")
        //         if !resetActiveLow.value {
        //             print("・Ensure that the reset is active high- pass --activeLow for activeLow.")
        //         }
        //         if internalCount == 0 {
        //             print("・Ensure that D flip-flop cell name starts with \(dffName).")
        //         }
        //         print("・Ensure that there are no other asynchronous resets anywhere in the circuit.")
        //     }
        // }
        // print("Done.")

    } catch {
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }
    return EX_OK
}