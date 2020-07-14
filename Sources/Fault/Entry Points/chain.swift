import Foundation
import CommandLineKit
import PythonKit
import Defile

/*
    - Add inverter to tck in case of negedge triggered
    - BB I/O ports
    - Fix clock sources statement 2
    - clock mux needs to get added to every flip-flop / not if we don't work with the CTS
    - insert isolating FFs check which chain are you choosing
*/

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

    let clockInv = StringOption(
        longFlag: "clockn",
        helpMessage: "Negedge triggered clk tree source name (Default: none)"
    )
    cli.addOptions(clockInv)

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

    let isolated = StringOption(
        longFlag: "isolating",
        helpMessage: "Isolated modules .v file from the scan-chain (Hard un-scannable blocks). (Default: none)"
    )
    cli.addOptions(isolated)

    let scanOpt = EnumOption<scanStructure>(
        longFlag: "scan",
        helpMessage: "Specifies scan-chain strucutre: one, multi. (Default: one)"
    )
    cli.addOptions(scanOpt)

    var names: [String: (default: String, option: StringOption)] = [:]

    for (name, value) in [
        ("sin", "boundary scan register serial data in"),
        ("sout", "boundary scan register serial data out"),
        ("mode", "boundary scan cell mode"),
        ("shift", "boundary scan cell shift"),
        ("clockDR", "boundary scan cell clock DR"),
        ("update", "boundary scan cell update"),
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

    let scanStructure = scanOpt.value ?? .one
    var scanChains: [ScanChain] = []
    var bsChain: ScanChain? 

    do {
        let (_, inputs, outputs) = try Port.extract(from: definition)

        let testingName = names["shift"]!.option.value ?? names["shift"]!.default
        let inputName = names["sin"]!.option.value ?? names["sin"]!.default
        let outputName = names["sout"]!.option.value ?? names["sout"]!.default
        let tckName = names["tck"]!.option.value ?? names["tck"]!.default

        let modeName = names["mode"]!.option.value ?? names["mode"]!.default
        let clockDRName = names["clockDR"]!.option.value ?? names["clockDR"]!.default
        let updateName = names["update"]!.option.value ?? names["update"]!.default
        
        let resetName = resetOpt.value ?? defaultBoundaryReset
        let clockName = clockOpt.value ?? ""

        switch scanStructure {
        case .one: 
            scanChains.append(
                ScanChain(
                    sin: inputName,
                    sout: outputName,
                    shift: testingName,
                    clock: "__clk_source__",
                    kind: .posedge,
                    using: Node
                )
            )
            break
        case .multi:
            for i in 1..<3 {
                scanChains.append(
                    ScanChain(
                        sin: "\(inputName)_\(i)",
                        sout: "\(outputName)_\(i)",
                        shift: "\(testingName)_\(i)",
                        clock: "__clk_source_\(i)__",
                        kind: (i==1) ? .posedge : .negedge,
                        using: Node
                    )
                )
            }
            bsChain = ScanChain(
                sin: "bs_\(inputName)",
                sout: "bs_\(outputName)",
                shift: "bs_\(testingName)",
                clock: tckName,
                kind: .boundary,
                using: Node
            )
            break
        }

        // MARK: Register chaining original module
        let statements = Python.list()
        statements.append(Node.Input(tckName))

        let ports = Python.list(definition.portlist.ports)
        ports.append(Node.Port(tckName, Python.None, Python.None, Python.None))

        for chain in scanChains {
            ports.append(Node.Port(chain.sin, Python.None, Python.None, Python.None))
            ports.append(Node.Port(chain.shift, Python.None, Python.None, Python.None))
            ports.append(Node.Port(chain.sout, Python.None, Python.None, Python.None))

            statements.append(Node.Input(chain.sin))
            statements.append(Node.Input(chain.shift))
            statements.append(Node.Output(chain.sout))
        }
        definition.portlist.ports = Python.tuple(ports)
        statements.extend(Python.list(definition.items))

        let partialChain = scanStructure == .one
        instanceLoop: for itemDeclaration in definition.items {
            let type = Python.type(itemDeclaration).__name__

            // Process gates
            if type == "InstanceList" {
                let instance = itemDeclaration.instances[0]
                if String(describing: instance.module).starts(with: dffName) {

                    var chainIndex = 0
                    for hook in instance.portlist {
                        if hook.portname == "CLK" {
                            if !String(describing: hook.argname).starts(with: clockName) {
                                if partialChain {
                                    continue instanceLoop
                                }
                                chainIndex = 1
                            }
                            else {
                                hook.argname = scanChains[chainIndex].clockIdentifier
                            }
                        }

                        if hook.portname == "D" {
                            let ternary = Node.Cond(
                                scanChains[chainIndex].shiftIdentifier,
                                scanChains[chainIndex].previousOutput,
                                hook.argname
                            )
                            hook.argname = ternary
                        }
                        if hook.portname == "Q" {
                           scanChains[chainIndex].previousOutput = hook.argname
                        }
                    }
                    scanChains[chainIndex].add (
                        name: String(describing: instance.name),
                        kind: .dff
                    )
                } else if let name = isolatedName {
                    // MARK: Isolating hard blocks
                   if String(describing: instance.module) == name {
                       print("Chaining hard module...")
                       let (_, inputs, _) = try Port.extract(from: isolatedOptional!)
                       let inputNames = inputs.map { $0.name }
                       let scCreator = scanCellCreator(
                            name: "ScanCell",
                            clock: scanChains[0].clock,
                            reset: resetName,
                            resetActive: resetActiveLow.value ? .low : .high,
                            shift: scanChains[0].shift,
                            using: Node
                        )
                       for hook in instance.portlist {
                            let hookType = Python.type(hook.argname).__name__
                            if hookType == "Concat" {
                                var list: [PythonObject] = []
                                let input = inputNames.contains(String(describing: hook.portname))
                                for (i, element) in  hook.argname.list.enumerated() {
                                    if [clockName, resetName].contains("\(element.name)") {
                                        continue
                                    }

                                    let outName = "__\(hook.portname)_\(i)__"
                                    statements.append(Node.Wire(outName))

                                    var cell: PythonObject
                                    if input {
                                        cell = scCreator.create(
                                            din: "\(element.name)",
                                            sin: "\(scanChains[0].previousOutput)",
                                            out: outName
                                        )
                                        scanChains[0].previousOutput = Node.Identifier(outName)
                                    } else {
                                        cell = scCreator.create(
                                            din: outName,
                                            sin: "\(scanChains[0].previousOutput)",
                                            out: "\(element.name)"
                                        )
                                        scanChains[0].previousOutput = Node.Identifier("\(element.name)")
                                    }
                                    statements.append(cell)
                                    list.append(Node.Identifier(outName))
                                    scanChains[0].add(
                                        name: String(describing: instance.name),
                                        kind: .dff
                                    ) 
                                }
                                hook.argname.list = Python.tuple(list)
                            } else {
                                if [clockName, resetName].contains("\(hook.argname)") {
                                    continue
                                }
                                let outName = "__\(hook.portname)__"
                                statements.append(Node.Wire(outName))
                                statements.append(
                                    scCreator.create(
                                        din: "\(hook.argname)",
                                        sin: "\(scanChains[0].previousOutput)",
                                        out: outName
                                    )
                                )
                                hook.argname = Node.Identifier(outName)
                                scanChains[0].previousOutput = Node.Identifier(outName)
                                scanChains[0].add(
                                    name: String(describing: instance.name),
                                    kind: .dff
                                ) 
                            }
                       }
                        let scLocation = output + ".sc_cell.v"

                        try File.open(scLocation, mode: .write) {
                            try $0.print(scCreator.cellDefinition)
                        }
                        let scanCells =
                            parse([scLocation])[0][dynamicMember: "description"].definitions
                    
                        let definitions = Python.list(description.definitions)
                        definitions.extend(scanCells)
                        description.definitions = Python.tuple(definitions)
                   }   
                }
                if let invertedClock = clockInv.value { 
                    if partialChain {
                        print("[Warning]: inverted clock is ignored in [one] scan-chain structure.")
                        continue
                    }

                    if String(describing: instance.module) == invertedClock {
                        for hook in instance.portlist {
                            if String(describing: hook.argname) == clockName {
                                let ternary = Node.Cond(
                                    scanChains[1].shiftIdentifier,
                                    Node.Unot(Node.Identifier(tckName)),
                                    Node.Identifier(clockName)
                                )
                                hook.argname = ternary
                            }
                        }
                    }
                }
            }
        }

        for chain in scanChains {
            let finalAssignment = Node.Assign(
                Node.Lvalue(chain.soutIdentifier),
                Node.Rvalue(chain.previousOutput)
            )
            statements.append(finalAssignment)
            let clockCond = Node.Cond(
                chain.shiftIdentifier,
                Node.Identifier(tckName),
                Node.Identifier(clockName)
            )
            let clkSource = Node.Assign(
                Node.Lvalue(chain.clockIdentifier),
                Node.Rvalue(clockCond)
            )
            statements.append(Node.Wire(chain.clock))
            statements.append(clkSource)
        }

        definition.items = Python.tuple(statements)
        definition.name = Python.str(alteredName)

        if clockOpt.value == nil {
            if scanChains[0].length > 0 {
                fputs("[Error]: Clock signal name for the internal logic isn't passed.\n", stderr)
                return EX_NOINPUT
            }
        }

        if scanChains[0].length == 0 {
            print("[Warning]: detected no internal flip flops triggered by \(clockName).Are you sure that flip-flop cell name starts with \(dffName) ? ")
        }
        if scanChains.count == 2 {
            if scanChains[1].length > 0 {
                print("[Warning]: detected flip flops triggered by different clock. Partial scan-chain is created.")
            }
        }

        // MARK: Chaining boundary registers
        print("Creating and chaining boundary flip-flops…")

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
                if let boundaryChain = bsChain {
                    ports.append(Node.Port(boundaryChain.sin, Python.None, Python.None, Python.None))
                    ports.append(Node.Port(boundaryChain.sout, Python.None, Python.None, Python.None))
                    ports.append(Node.Port(boundaryChain.shift, Python.None, Python.None, Python.None))
                    scanChains.append(boundaryChain)
                }
            }

            for chain in scanChains {
                statements.append(Node.Input(chain.sin))
                statements.append(Node.Input(chain.shift))
                statements.append(Node.Output(chain.sout))
            }

            if let clock = clockOpt.value {
                statements.append(Node.Input(clock))            
            }

            let inputName = scanChains.last!.sin
            let inputIdentifier = scanChains.last!.sinIdentifier 
            let outputIdentifier = scanChains.last!.soutIdentifier
            let shiftName = scanChains.last!.shift

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

                scanChains.last!.add(
                    name: String(describing: input.name),
                    kind: .input,
                    width: input.width
                )
            }

            // MARK: ports for chained module instance
            portArguments.append(Node.PortArg(
                tckName,
                Node.Identifier(tckName)
            ))
            for (i, chain) in scanChains.enumerated() {
                if i == 2 {
                    break
                }
                portArguments.append(Node.PortArg(
                    chain.sin,
                    (scanStructure == .multi) ? chain.sinIdentifier: Node.Identifier(inputName.uniqueName(counter))
                ))
                portArguments.append(Node.PortArg(
                    chain.shift,
                    chain.shiftIdentifier
                ))
                portArguments.append(Node.PortArg(
                    chain.sout,
                    (scanStructure == .multi) ? chain.soutIdentifier: Node.Identifier(inputName.uniqueName(counter + 1))
                ))

                if  (scanStructure == .one) {
                    counter = counter + 1
                }
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

                scanChains.last!.add(
                    name: String(describing: output.name),
                    kind: .output,
                    width: output.width
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

            return counter
        }()
        
        var chainCodable: [Chain] = []
        for chain in scanChains {
            chainCodable.append(
                Chain(
                    sin: chain.sin,
                    sout: chain.sout,
                    shift: chain.shift,
                    length: chain.length,
                    kind: chain.kind
                )
            )
        }

        let metadata = ChainMetadata(
            type: scanStructure,
            scanChains: chainCodable
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

        // // MARK: Verification
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
            for (i, chain) in scanChains.enumerated() {
                let verified = try Simulator.simulate(
                    verifying: definitionName,
                    in: output, 
                    isolated: isolated.value,
                    with: model,
                    ports: ports,
                    inputs: inputs,
                    outputs: outputs,
                    chainLength: chain.length,
                    clock: clockName,
                    tck: tckName,
                    reset: resetName,
                    sin: chain.sin,
                    sout: chain.sout,
                    resetActive: resetActiveLow.value ? .low : .high,
                    testing: chain.shift,
                    clockDR: clockDRName,
                    update: updateName,
                    mode: modeName,
                    output: output + ".chain_\(i)_tb.sv",
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
                    if chain.length == 0 {
                        print("・Ensure that D flip-flop cell name starts with \(dffName).")
                    }
                    print("・Ensure that there are no other asynchronous resets anywhere in the circuit.")
                }
           }
        }
        print("Done.")

    } catch {
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }
    return EX_OK
}