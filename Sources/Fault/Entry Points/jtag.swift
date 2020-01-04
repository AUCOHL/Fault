import Foundation
import CommandLineKit
import PythonKit
import Defile

func JTAGCreate(arguments: [String]) -> Int32{
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
        helpMessage: "Clock signal of core logic to use in simulation"
    )
    cli.addOptions(clockOpt)

    let resetOpt = StringOption(
        longFlag: "reset",
        helpMessage: "Reset signal of core logic to use in simulation."
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

    var names: [String: (default: String, option: StringOption)] = [:]

    for (name, value) in [
        ("sin", "BS chain serial data in"),
        ("sout", "BS chain serial data out"),
        ("shift", "BS chain shift enable"),
        ("capture", "BS chain capture enable"),
        ("update", "BS chain update enable"),
        ("tms", "JTAG test mode select"),
        ("tck", "JTAG test clock signal"),
        ("tdi", "JTAG test data input"),
        ("tdo", "JTAG test data output"),
        ("trst", "JTAG test reset signal. (Always active low.)")
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

    let output = filePath.value ?? "\(file).jtag.v"
    let intermediate = output + ".intermediate.v"
    let tapLocation = "RTL/JTAG/tap_top.v"
    let triLocation = "RTL/JTAG/tri_state.v"

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

    let sinName = names["sin"]!.option.value ?? names["sin"]!.default
    let soutName = names["sout"]!.option.value ?? names["sout"]!.default
    let shiftName = names["shift"]!.option.value ?? names["shift"]!.default
    let updateName = names["update"]!.option.value ?? names["update"]!.default
    let captureName = names["capture"]!.option.value ?? names["capture"]!.default
    let tmsName = names["tms"]!.option.value ?? names["tms"]!.default
    let tdiName = names["tdi"]!.option.value ?? names["tdi"]!.default
    let tdoName = names["tdo"]!.option.value ?? names["tdo"]!.default
    let tckName = names["tck"]!.option.value ?? names["tck"]!.default
    let trstName = names["trst"]!.option.value ?? names["trst"]!.default

    // MARK: Internal signals
    print("Adding JTAG port…")
    let definitionName = String(describing: definition.name)
    let alteredName = "__DESIGN__UNDER__TEST__"
    let trstHighName = "__trst_high__"

    do {
        let (_, inputs, outputs) = try Port.extract(from: definition)
        definition.name = Python.str(alteredName);
      
        let ports = Python.list(definition.portlist.ports)

        let dffCount: Int = {
            var counter = 0
            for itemDeclaration in definition.items {
                let type = Python.type(itemDeclaration).__name__
                // Process gates
                if type == "InstanceList" {
                    let instance = itemDeclaration.instances[0]
                    if String(describing: instance.module).starts(with: "DFF") {
                        counter += 1
                    }
                }
            }
            return counter
        }()

        let scanChainPorts = [
            sinName,
            soutName,
            shiftName,
            updateName,
            captureName,
        ]
        let topModulePorts = Python.list(ports.filter {
            !scanChainPorts.contains(String($0.name)!)
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
        statements.append(Node.Input(trstName))
        statements.append(Node.Output(tdoName))
        
        let portArguments = Python.list()

        for input in inputs {
            if(!scanChainPorts.contains(input.name)){
                statements.append(Node.Input(input.name))
                portArguments.append(Node.PortArg(
                    input.name,
                    Node.Identifier(input.name)
                ))
            }
            else {
                let portIdentifier = (input.name == sinName) ? tdiName : input.name
                portArguments.append(Node.PortArg(
                    input.name,
                    Node.Identifier(portIdentifier)
                ))
            }
           
        }

        for output in outputs {
            if(!scanChainPorts.contains(output.name)){
                statements.append(Node.Output(output.name))
            }
            portArguments.append(Node.PortArg(
                output.name,
                Node.Identifier(output.name)
            ))
        }
            
        // MARK: tap module  
        let file = "RTL/JTAG/tapConfig.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: file), options: .mappedIfSafe)
        
        guard let jtagInfo = try? JSONDecoder().decode(JTAGInfo.self, from: data) else {
            fputs("File '\(file)' is invalid.\n", stderr)
            return EX_DATAERR
        }

        let jtagCreator = JTAGCreator(
            name: "tap_top",
            using: Node
        )
        let jtagModule =  jtagCreator.create(
            jtagInfo: jtagInfo, 
            tms: tmsName,
            tck: tckName,
            tdi: tdiName,
            tdo: tdoName,
            trst: trstHighName
        )
        var wireDeclarations = jtagModule.wires
        wireDeclarations.append(Node.Wire(trstHighName))
        
        // add sout and shift wires
        statements.extend(wireDeclarations)
        statements.extend([
            Node.Wire(soutName),
            Node.Wire(shiftName),
            Node.Wire(captureName),
            Node.Wire(updateName)
        ])
        statements.append(jtagModule.tapModule)

        // negate reset to make it active high
        statements.append(Node.Assign(
            Node.Lvalue(Node.Identifier(trstHighName)),
            Node.Rvalue(Node.Unot(Node.Identifier(trstName)))
        ))
        // sout and bschain_assign_statement
        statements.append(Node.Assign(
            Node.Lvalue(Node.Identifier(jtagInfo.tdiSignals.bsChain)),
            Node.Rvalue(Node.Identifier(soutName))
        ))
        //shift enable assign 
        statements.append(Node.Assign(
            Node.Rvalue(Node.Identifier(shiftName)),
            Node.Lvalue(Node.Identifier(jtagInfo.tapStates.shift))
        ))
        statements.append(Node.Assign(
            Node.Rvalue(Node.Identifier(captureName)),
            Node.Lvalue(Node.Identifier(jtagInfo.tapStates.capture))
        ))
        statements.append(Node.Assign(
            Node.Rvalue(Node.Identifier(updateName)),
            Node.Lvalue(Node.Identifier(jtagInfo.tapStates.update))
        ))
        // tdo tri-state buffer
        // let triArguments = [
        //     Node.PortArg("in",Node.Identifier(jtagInfo.pads.tdo)),
        //     Node.PortArg("oe",Node.Identifier(jtagInfo.pads.tdoEn)),
        //     Node.PortArg("out",Node.Identifier(tdoName))
        // ]

        // let triModuleInstance = Node.Instance(
        //     "Tristate",
        //     "__triState__",
        //     Python.tuple(triArguments),
        //     Python.tuple()
        // )

        // statements.append(Node.InstanceList(
        //     "Tristate",
        //     Python.tuple(),
        //     Python.tuple([triModuleInstance])
        // ))


        let sens = Node.Sens(Node.Identifier(jtagInfo.pads.tdoEn), "level")
        let senslist = Node.SensList([ sens ])

        let tdoAssignTrue = Node.BlockingSubstitution(
            Node.Lvalue(Node.Identifier(tdoName)),
            Node.Rvalue(Node.Identifier(jtagInfo.pads.tdo))
        )
        let tdoAssignFalse = Node.BlockingSubstitution(
            Node.Lvalue(Node.Identifier(tdoName)),
            Node.Rvalue(Node.IntConst("z"))
        )
        let ifTdoEn = Node.IfStatement(
            Node.Identifier(jtagInfo.pads.tdoEn),
            Node.Block([ tdoAssignTrue ]),
            Node.Block([ tdoAssignFalse ])
        ) 
        let ifStatement = Node.Block([ ifTdoEn ])

        let always = Node.Always(senslist, ifStatement)

        statements.append(always)

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

        // let triDefinition =
        //     parse([triLocation])[0][dynamicMember: "description"].definitions
        let tapDefinition =
            parse([tapLocation])[0][dynamicMember: "description"].definitions
        
        let definitions = Python.list(description.definitions)
        
        //definitions.extend(triDefinition)
        definitions.extend(tapDefinition)
        definitions.append(supermodel)
        description.definitions = Python.tuple(definitions)

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

        // MARK: Yosys
        print("Resynthesizing with yosys…")
        let result = "echo '\(script)' | '\(yosysExecutable)' > /dev/null".sh()

        if result != EX_OK {
            fputs("A yosys error has occurred.\n", stderr)
            return Int32(result)
        }
        print("Done.")

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
            let boundaryCount = inputs.count + outputs.count - 7
            let internalCount = dffCount - boundaryCount * 2;
           
            let verified = try Simulator.simulate(
                verifying: definitionName,
                in: output,
                with: model,
                ports: ports,
                inputs: inputs,
                outputs: outputs,
                boundaryCount: boundaryCount,
                internalCount: internalCount,
                clock: clockOpt.value!,
                reset: resetOpt.value!,
                resetActive: resetActiveLow.value ? .low : .high,
                tms: tmsName,
                tdi: tdiName,
                tck: tckName,
                tdo: tdoName,
                trst: trstName,
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
        }
    } catch{
        fputs("Internal software error: \(error)", stderr)
        return EX_SOFTWARE
    }
    
    return EX_OK

}