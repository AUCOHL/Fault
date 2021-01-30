import Foundation
import CommandLineKit
import PythonKit
import Defile

func jtagCreate(arguments: [String]) -> Int32 {
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
        required: true,
        helpMessage: "Liberty file. (Required.)"
    )
    cli.addOptions(liberty)

    let testvectors = StringOption(
        shortFlag: "t",
        longFlag: "testVectors",
        helpMessage:  ".bin file for test vectors."
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

    let defs = StringOption(
        longFlag: "define",
        helpMessage: "define statements to include during simulations. (Default: none)"
    )
    cli.addOptions(defs)

    let include = StringOption(
        longFlag: "inc",
        helpMessage: "Verilog files to include during simulations. (Default: none)"
    )
    cli.addOptions(include)

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
        ("tdo_paden_o", "TDO Enable pad (active low) "),
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
        Stderr.print("File '\(file)' not found.")
        return EX_NOINPUT
    }
    
    let (_, boundaryCount, internalCount) = ChainMetadata.extract(file: file)  
    
    let clockName = clockOpt.value!
    let resetName = resetOpt.value!

    var ignoredInputs: Set<String>
        = Set<String>(ignored.value?.components(separatedBy: ",").filter {$0 != ""} ?? [])
    
    let defines: Set<String>
        = Set<String>(defs.value?.components(separatedBy: ",").filter {$0 != ""} ?? [])

    ignoredInputs.insert(clockName)
    ignoredInputs.insert(resetName)

    if let libertyTest = liberty.value {
        if !fileManager.fileExists(atPath: libertyTest) {
            Stderr.print("Liberty file '\(libertyTest)' not found.")
            return EX_NOINPUT
        }
        if !libertyTest.hasSuffix(".lib") {
            Stderr.print(
                "Warning: Liberty file provided does not end with .lib."
            )
        }
    }

    if let modelTest = verifyOpt.value {
        if !fileManager.fileExists(atPath: modelTest) {
            Stderr.print("Cell model file '\(modelTest)' not found.")
            return EX_NOINPUT
        }
        if !modelTest.hasSuffix(".v") && !modelTest.hasSuffix(".sv") {
            Stderr.print(
                "Warning: Cell model file provided does not end with .v or .sv."
            )
        }
    }

    if let tvTest = testvectors.value {
        if !fileManager.fileExists(atPath: tvTest) {
            Stderr.print("Test vectors file '\(tvTest)' not found.")
            return EX_NOINPUT
        }
        if !tvTest.hasSuffix(".bin") {
            Stderr.print(
                "Warning: Test vectors file provided does not end with .bin."
            )
        }
        guard let _ = goldenOutput.value else {
            Stderr.print("Using goldenOutput (-g) option is required '\(tvTest)'.")
            return EX_NOINPUT
        }
    }

    let includeFiles: Set<String>
        = Set<String>(include.value?.components(separatedBy: ",").filter {$0 != ""} ?? [])
    
    var includeString = ""
    for file in includeFiles {
        if !fileManager.fileExists(atPath: file) {
            Stderr.print("Verilog file '\(file)' not found.")
            return EX_NOINPUT
        }
        includeString += """
            `include "\(file)"
        """
    }
 
    let output = filePath.value ?? "\(file).jtag.v"
    let intermediate = output + ".intermediate.v"

    let libertyFile = liberty.value!

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
        Stderr.print("No module found.")
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
    let tdoenableName = names["tdo_paden_o"]!.option.value 
        ?? names["tdo_paden_o"]!.default
    let tckName = names["tck"]!.option.value 
        ?? names["tck"]!.default
    let trstName = names["trst"]!.option.value 
        ?? names["trst"]!.default

    // MARK: Internal signals
    print("Creating top module…")
    let definitionName = String(describing: definition.name)
    let alteredName = "__DESIGN__UNDER__TEST__"

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
        topModulePorts.append(Node.Port(
            tdoenableName, Python.None, Python.None, Python.None))

        let statements = Python.list()
        statements.append(Node.Input(tmsName))
        statements.append(Node.Input(tckName))
        statements.append(Node.Input(tdiName))
        statements.append(Node.Output(tdoName))
        statements.append(Node.Output(tdoenableName))
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
        print("Stitching tap port…") 
        // let config = "RTL/JTAG/config.json"
        // if !fileManager.fileExists(atPath: config) {
        //     Stderr.print("JTAG configuration file '\(config)' not found.")
        //     return EX_NOINPUT
        // }

        // let data = try Data(contentsOf: URL(fileURLWithPath: config), options: .mappedIfSafe)
        // guard let tapInfo = try? JSONDecoder().decode(TapInfo.self, from: data) else {
        //     Stderr.print("File '\(config)' is invalid.")
        //     return EX_DATAERR
        // }
        let tapInfo = TapInfo.default

        let tapCreator = TapCreator(
            name: "tap_wrapper",
            using: Node
        )
        let tapModule =  tapCreator.create(
            tapInfo: tapInfo, 
            tms: tmsName,
            tck: tckName,
            tdi: tdiName,
            tdo: tdoName,
            tdoEnable_n: tdoenableName,
            trst: trstName,
            sin: sinName,
            sout: soutName,
            shift: shiftName,
            test: testName
        )

        // // TDO tri-state enable assignment
        // let ternary = Node.Cond(
        //     Node.Unot(Node.Identifier(tapInfo.tap.tdoEnable_n)),
        //     Node.Identifier(tapInfo.tap.tdo),
        //     Node.IntConst("1'bz")
        // )
        // let tdoAssignment = Node.Assign(
        //     Node.Lvalue(Node.Identifier(tdoName)),
        //     Node.Rvalue(ternary)
        // )

        // statements.append(tdoAssignment)
        statements.extend(tapModule.wires)
        statements.append(tapModule.tapModule)

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

        let tempDir = "\(NSTemporaryDirectory())"


        let tapLocation = "\(tempDir)/top.v"
        let wrapperLocation = "\(tempDir)/wrapper.v"

        do {
            try File.open(tapLocation, mode: .write) { 
                try $0.print(TapCreator.top)
            }
            try File.open(wrapperLocation, mode: .write) {
                try $0.print(TapCreator.wrapper)
            }

        } catch {

        }

        let tapDefinition =
            parse([tapLocation])[0][dynamicMember: "description"].definitions
        
        let wrapperDefinition =
            parse([wrapperLocation])[0][dynamicMember: "description"].definitions
        
        try? File.delete(tapLocation)
        try? File.delete(wrapperLocation)

        let definitions = Python.list(description.definitions)
        definitions.extend(tapDefinition)
        definitions.extend(wrapperDefinition)
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
            Stderr.print("A yosys error has occurred.")
            return Int32(result)
        }
        if verifyOpt.value == nil {
            print("Done.")
        }

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
                Stderr.print("No module found.")
                return EX_DATAERR
            }
            let (ports, inputs, outputs) = try Port.extract(from: definition)
            let verified = try Simulator.simulate(
                verifying: definitionName,
                in: output, // DEBUG
                isolating: blackbox.value,
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
                defines: defines,
                includes: includeString,
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
                print("Generating testbench for test vectors…")
                let behavior
                    = Array<Simulator.Behavior>(
                        repeating: .holdHigh,
                        count: ignoredInputs.count
                    )
                let (vectorCount, vectorLength) = binMetadata.extract(file: tvFile)
                let (_, outputLength) = binMetadata.extract(file: goldenOutput.value!)
                let testbecnh = output + ".tv" + ".tb.sv"
                let verified = try Simulator.simulate(
                    verifying: definitionName,
                    in: output, // DEBUG
                    isolating: blackbox.value,
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
                    defines: defines,
                    includes: includeString,
                    using: iverilogExecutable,
                    with: vvpExecutable
                )
                if (verified) {
                    print("Test vectors verified successfully.")
                } else {
                    print("Test vector simulation failed.")
                    if !resetActiveLow.value { // default is ignored inputs are held high
                        print("・Ensure that ignored inputs in the simulation are held low. Pass --holdLow if reset is active high.")
                    }
                }  
            }
        }
    } catch {
        Stderr.print("Internal software error: \(error)")
        return EX_SOFTWARE
    }
    
    return EX_OK

}