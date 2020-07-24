import Foundation
import CommandLineKit
import PythonKit
import Defile

func jtagCreate(arguments: [String]) -> Int32 {
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
        helpMessage: "Path to the output file. (Default: input + .jtag.v)"
    )
    cli.addOptions(filePath)

    let verifyOpt = StringOption(
        shortFlag: "c",
        longFlag: "cellModel",
        helpMessage: "Verify JTAG port using given cell model."
    )
    cli.addOptions(verifyOpt)

    let clockOpt = StringOption(
        longFlag: "clock",
        required: true,
        helpMessage: "Clock signal of core logic to use in simulation. (Required)"
    )
    cli.addOptions(clockOpt)

    let resetOpt = StringOption(
        longFlag: "reset",
        required: true,
        helpMessage: "Reset signal of core logic to use in simulation. (Required)"
    )
    cli.addOptions(resetOpt)

    let resetActiveLow = BoolOption(
        longFlag: "activeLow",
        helpMessage: "Reset signal of core logic is active low instead of active high."
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

    let testvectors = StringOption(
        shortFlag: "t",
        longFlag: "testVectors",
        helpMessage: 
            " .bin file for test vectors."
    )
    cli.addOptions(testvectors)

    let goldenOutput = StringOption(
        shortFlag: "g",
        longFlag: "goldenOutput",
        helpMessage: 
            " .bin file for golden output."
    )
    cli.addOptions(goldenOutput)

    let ignored = StringOption(
        shortFlag: "i",
        longFlag: "ignoring",
        helpMessage: "Inputs,to,ignore,separated,by,commas. (Default: none)"
    )
    cli.addOptions(ignored)

    let blackbox = StringOption(
        longFlag: "blackbox",
        helpMessage: "Blackbox module (.v) to use for simulation. (Default: none)"
    )
    cli.addOptions(blackbox)

    var names: [String: (default: String, option: StringOption)] = [:]

    for (name, value) in [
        ("sin", "scan-chain serial data in"),
        ("sout", "scan-chain serial data out"),
        ("shift", "scan-chain shift enable"),
        ("test", "scan-chain test enable"),
        ("tms", "JTAG test mode select"),
        ("tck", "JTAG test clock"),
        ("tdi", "JTAG test data input"),
        ("tdo", "JTAG test data output"),
        ("trst", "JTAG test reset (active low)")
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
    
    let (_, boundaryCount, internalCount) = ChainMetadata.extract(file: file)  
    
    let clockName = clockOpt.value!
    let resetName = resetOpt.value!

    var ignoredInputs: Set<String>
        = Set<String>(ignored.value?.components(separatedBy: ",") ?? [])
    ignoredInputs.insert(clockName)
    ignoredInputs.insert(resetName)

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

    if let tvTest = testvectors.value {
        if !fileManager.fileExists(atPath: tvTest) {
            fputs("Test vectors file '\(tvTest)' not found.\n", stderr)
            return EX_NOINPUT
        }
        if !tvTest.hasSuffix(".bin") {
            fputs(
                "Warning: Test vectors file provided does not end with .bin. \n",
                stderr
            )
        }
        guard let _ = goldenOutput.value else {
            fputs("Using goldenOutput (-g) option is required '\(tvTest)'.\n", stderr)
            return EX_NOINPUT
        }
    }

    let output = filePath.value ?? "\(file).jtag.v"
    let intermediate = output + ".intermediate.v"
    let tapLocation = "RTL/JTAG/tap_top.v"

    let libertyFile = defaultLiberty ?
        liberty.value ??
        "\(env["FAULT_INSTALL_PATH"]!)/FaultInstall/Tech/osu035/osu035_stdcells.lib" :
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

    let sinName = names["sin"]!.option.value 
        ?? names["sin"]!.default
    let soutName = names["sout"]!.option.value
        ?? names["sout"]!.default
    let shiftName = names["shift"]!.option.value
        ?? names["shift"]!.default
    let testName = names["test"]!.option.value
        ?? names["test"]!.default
    let tmsName = names["tms"]!.option.value 
        ?? names["tms"]!.default
    let tdiName = names["tdi"]!.option.value 
        ?? names["tdi"]!.default
    let tdoName = names["tdo"]!.option.value 
        ?? names["tdo"]!.default
    let tckName = names["tck"]!.option.value 
        ?? names["tck"]!.default
    let trstName = names["trst"]!.option.value 
        ?? names["trst"]!.default

    // MARK: Internal signals
    print("Adding JTAG port…")
    let definitionName = String(describing: definition.name)
    let alteredName = "__DESIGN__UNDER__TEST__"
    let trstHighName = "__trst_high__"

    do {
        let (_, inputs, outputs) = try Port.extract(from: definition)
        definition.name = Python.str(alteredName);
        let ports = Python.list(definition.portlist.ports)

        let chainPorts: [String] = [
            sinName,
            soutName,
            shiftName,
            tckName,
            testName
        ] 
        let topModulePorts = Python.list(ports.filter {
            !chainPorts.contains(String($0.name)!)
        })

        topModulePorts.append(Node.Port(
            tmsName, Python.None, Python.None, Python.None))
        topModulePorts.append(Node.Port(
            tckName, Python.None, Python.None, Python.None))
        topModulePorts.append(Node.Port(
            tdiName, Python.None, Python.None, Python.None))
        topModulePorts.append(Node.Port(
            tdoName, Python.None, Python.None, Python.None))
        topModulePorts.append(Node.Port(
            trstName, Python.None, Python.None, Python.None))

        let statements = Python.list()
        statements.append(Node.Input(tmsName))
        statements.append(Node.Input(tckName))
        statements.append(Node.Input(tdiName))
        statements.append(Node.Output(tdoName))
        statements.append(Node.Input(trstName))

        let portArguments = Python.list()
        for input in inputs {
            if(!chainPorts.contains(input.name)){
                let inputStatement = Node.Input(input.name)
                portArguments.append(Node.PortArg(
                    input.name,
                    Node.Identifier(input.name)
                ))
                if input.width > 1 {
                    let width = Node.Width(
                        Node.Constant(input.from),
                        Node.Constant(input.to)
                    )
                    inputStatement.width = width
                }
                statements.append(inputStatement)
            }
            else {
                let portIdentifier = input.name
                portArguments.append(Node.PortArg(
                    input.name,
                    Node.Identifier(portIdentifier)
                ))
            }
        }

        for output in outputs {
            if(!chainPorts.contains(output.name)){
                let outputStatement = Node.Output(output.name)
                if output.width > 1 {
                    let width = Node.Width(
                        Node.Constant(output.from),
                        Node.Constant(output.to)
                    )
                    outputStatement.width = width
                }
                statements.append(outputStatement)
            }
            portArguments.append(Node.PortArg(
                output.name,
                Node.Identifier(output.name)
            ))
        }
            
        // MARK: tap module 
        print("Stitching tap port...") 
        let tapConfig = "RTL/JTAG/tapConfig.json"
        if !fileManager.fileExists(atPath: tapConfig) {
            fputs("JTAG configuration file '\(tapConfig)' not found.\n", stderr)
            return EX_NOINPUT
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: tapConfig), options: .mappedIfSafe)
        
        guard let jtagInfo = try? JSONDecoder().decode(jtagInfo.self, from: data) else {
            fputs("File '\(tapConfig)' is invalid.\n", stderr)
            return EX_DATAERR
        }

        let tapCreator = jtagCreator(
            name: "tap_top",
            using: Node
        )
        let jtagModule =  tapCreator.create(
            jtagInfo: jtagInfo, 
            tms: tmsName,
            tck: tckName,
            tdi: tdiName,
            tdo: tdoName,
            trst: trstHighName
        )
        var wireDeclarations = jtagModule.wires
        wireDeclarations.append(Node.Wire(trstHighName))

        statements.extend(wireDeclarations)
        statements.extend([
            Node.Wire(shiftName),
            Node.Wire(testName),
            Node.Wire(sinName),
            Node.Wire(soutName)
        ])

        statements.append(jtagModule.tapModule)
        // negate reset to make it active high
        statements.append(Node.Assign(
            Node.Lvalue(Node.Identifier(trstHighName)),
            Node.Rvalue(Node.Unot(Node.Identifier(trstName)))
        ))

        let tdiIdentifier = Node.Identifier(jtagInfo.inputTdi.chain)
        let shiftIdentifier = Node.And(
           Node.Or(
                Node.Identifier(jtagInfo.states.pause),
                Node.Or(
                    Node.Identifier(jtagInfo.states.shift),
                    Node.Identifier(jtagInfo.states.exit1)
                )
            ),
            Node.Identifier(jtagInfo.selects.preloadChain)
        )
        // sout and tdi signals assignment
        statements.append(Node.Assign(
            Node.Rvalue(Node.Identifier(shiftName)),
            Node.Lvalue(shiftIdentifier)
        ))
        // TDO tri-state enable assignment
        let ternary = Node.Cond(
            Node.Identifier(jtagInfo.pads.tdoEn),
            Node.Identifier(jtagInfo.pads.tdo),
            Node.IntConst("1'bz")
        )
        let tdoAssignment = Node.Assign(
            Node.Lvalue(Node.Identifier(tdoName)),
            Node.Rvalue(ternary)
        )
        statements.append(tdoAssignment)
        // Test mode assignment
        let testCondition = Node.Unot(
            Node.Or(
                Node.Identifier(jtagInfo.states.idle), 
                Node.Identifier(jtagInfo.states.reset)
            )
        )
        let testAssignment = Node.Assign(
            Node.Lvalue(Node.Identifier(testName)),
            Node.Rvalue(testCondition)
        )
        statements.append(testAssignment)

        // sin assignment
        let sinAssignment = Node.Assign(
            Node.Lvalue(Node.Identifier(sinName)),
            Node.Rvalue(Node.Identifier(jtagInfo.tdoSignal))
        )
        statements.append(sinAssignment)

        // sout negedge sample
        let soutRegister = Node.Reg("sout_sampled")
        let sens = Node.Sens(Node.Identifier(tckName), "negedge")
        let senslist = Node.SensList([ sens ])
        let statement = Node.Block([ Node.NonblockingSubstitution(
            Node.Lvalue(Node.Identifier("sout_sampled")),
            Node.Rvalue(Node.Identifier(soutName))
        )])
        let always = Node.Always(senslist, statement)
        statements.append(soutRegister)
        statements.append(always)
        // chain_tdi ssignment
        statements.append(Node.Assign(
            Node.Rvalue(tdiIdentifier),
            Node.Lvalue(Node.Identifier("sout_sampled"))
        ))

        let submoduleInstance = Node.Instance(
            alteredName,
            "__dut__",
            Python.tuple(portArguments),
            Python.tuple()
        )

        statements.append(Node.InstanceList(
            alteredName,
            Python.tuple(),
            Python.tuple([submoduleInstance])
        ))

        let supermodel = Node.ModuleDef(
            definitionName,
            Python.None,
            Node.Portlist(Python.tuple(topModulePorts)),
            Python.tuple(statements)
        )

        let tapDefinition =
            parse([tapLocation])[0][dynamicMember: "description"].definitions

        let definitions = Python.list(description.definitions)
        
        definitions.extend(tapDefinition)
        definitions.append(supermodel)
        description.definitions = Python.tuple(definitions)

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
        print("Done.")

        guard let content = File.read(output) else {
            throw "Could not re-read created file."
        }

        try File.open(output, mode: .write) {
            try $0.print(String.boilerplate)
            try $0.print(content)
        }

        // MARK: Verification
        if let model = verifyOpt.value {
            print("Verifying tap port integrity…")
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
                in: output, // DEBUG
                with: model,
                ports: ports,
                inputs: inputs,
                outputs: outputs,
                chainLength: boundaryCount + internalCount,
                clock: clockName,
                reset: resetName,
                resetActive: resetActiveLow.value ? .low : .high,
                tms: tmsName,
                tdi: tdiName,
                tck: tckName,
                tdo: tdoName,
                trst: trstName,
                output: output + ".tb.sv",
                using: iverilogExecutable,
                with: vvpExecutable
            )
            print("Done.")
            if (verified) {
                print("Tap port verified successfully.")
            } else {
                print("Tap port verification failed.")
                print("・Ensure that clock and reset signals, if they exist are passed as such to the program.")
                if !resetActiveLow.value {
                    print("・Ensure that the reset is active high- pass --activeLow for activeLow.")
                }
                print("・Ensure that there are no other asynchronous resets anywhere in the circuit.")
            }

            // MARK: Test bench
            if let tvFile = testvectors.value {
                print("Generating testbench for test vectors...")
                let behavior
                    = Array<Simulator.Behavior>(
                        repeating: .holdHigh,
                        count: ignoredInputs.count
                    )
                let (vectorCount, vectorLength) = binMetadata.extract(file: tvFile)
                let (_, outputLength) = binMetadata.extract(file: goldenOutput.value!)
                let testbecnh = (filePath.value ?? file) + ".tb.sv"
                let verified = try Simulator.simulate(
                    verifying: definitionName,
                    in: output, // DEBUG
                    with: model,
                    ports: ports,
                    inputs: inputs,
                    ignoring: ignoredInputs,
                    behavior: behavior,
                    outputs: outputs,
                    clock: clockName,
                    reset: resetName,
                    resetActive: resetActiveLow.value ? .low : .high,
                    tms: tmsName,
                    tdi: tdiName,
                    tck: tckName,
                    tdo: tdoName,
                    trst: trstName,
                    output: testbecnh,
                    chainLength: internalCount + boundaryCount, 
                    vecbinFile: testvectors.value!,
                    outbinFile: goldenOutput.value!,
                    vectorCount: vectorCount,
                    vectorLength: vectorLength,
                    outputLength: outputLength,
                    using: iverilogExecutable,
                    with: vvpExecutable
                )
                print("Done.")
                if (verified) {
                    print("Test vectors verified successfully.")
                } else {
                    print("Test vector simulation failed.")
                }  
            }
        }
    } catch {
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }
    
    return EX_OK

}