// Copyright (C) 2019 The American University in Cairo
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Collections
import CommandLineKit
import Defile
import Foundation
import PythonKit
import Yams

func chainInternal(
    Node: PythonObject,
    sclConfig: SCLConfiguration,
    module: Module,
    blackboxModules: OrderedDictionary<String, Module>,
    bsrCreator: BoundaryScanRegisterCreator,
    clockName: String,
    resetName _: String,
    resetActive _: Simulator.Active,
    shiftName: String,
    inputName: String,
    outputName: String,
    testName: String,
    tckName: String,
    invClockName: String?,
    ignoredInputs: Set<String>
) throws -> [ChainRegister] {
    // Modifies module definition in-place to create scan-chain.
    // Changes name to .original to differentate from new top level.
    print("Chaining internal flip-flops…")
    let alteredName = "\\\(module.name).original"

    var internalOrder: [ChainRegister] = []

    let shiftIdentifier = Node.Identifier(shiftName)
    let inputIdentifier = Node.Identifier(inputName)
    let outputIdentifier = Node.Identifier(outputName)

    let clkSourceName = "__clk_source__"
    let clkSourceId = Node.Identifier(clkSourceName)
    let invClkSourceName = "__clk_source_n__"
    var invClkSourceId: PythonObject?

    var statements: [PythonObject] = []
    statements.append(Node.Input(inputName))
    statements.append(Node.Output(outputName))
    statements.append(Node.Input(shiftName))
    statements.append(Node.Input(tckName))
    statements.append(Node.Input(testName))
    statements.append(Node.Wire(clkSourceName))

    if invClockName != nil {
        statements.append(Node.Wire(invClkSourceName))
    }

    var ports = [PythonObject](module.definition.portlist.ports)!
    ports.append(Node.Port(inputName, Python.None, Python.None, Python.None))
    ports.append(Node.Port(shiftName, Python.None, Python.None, Python.None))
    ports.append(Node.Port(outputName, Python.None, Python.None, Python.None))
    ports.append(Node.Port(tckName, Python.None, Python.None, Python.None))
    ports.append(Node.Port(testName, Python.None, Python.None, Python.None))
    module.definition.portlist.ports = Python.tuple(ports)

    var counter = 0
    let newShiftWire = {
        () in
        let name = "__chain_\(counter)__"
        counter += 1
        statements.append(Node.Decl([Node.Wire(name)]))
        return Node.Identifier(name)
    }
    var previousOutput = newShiftWire()

    statements.append(Node.Assign(previousOutput, inputIdentifier))

    let fnmatch = Python.import("fnmatch")

    var muxCreator: MuxCreator?
    if let muxInfo = sclConfig.muxInfo {
        muxCreator = MuxCreator(using: Node, muxInfo: muxInfo)
    }
    var warn = false
    for itemDeclaration in module.definition.items {
        let type = Python.type(itemDeclaration).__name__
        // Process gates
        if type == "InstanceList" {
            let instance = itemDeclaration.instances[0]
            let moduleName = String(describing: instance.module)
            let instanceName = String(describing: instance.name)
            if let dffinfo = getMatchingDFFInfo(from: sclConfig.dffMatches, for: moduleName, fnmatch: fnmatch) {
                for hook in instance.portlist {
                    let portnameStr = String(describing: hook.portname)
                    if portnameStr == dffinfo.clk {
                        if String(describing: hook.argname) == clockName {
                            hook.argname = clkSourceId
                        } else {
                            warn = true
                        }
                    }
                    if portnameStr == dffinfo.d {
                        if let mc = muxCreator {
                            let (muxCellDecls, muxWireDecls, muxOut) = mc.create(for: instanceName, selection: shiftIdentifier, a: previousOutput, b: hook.argname)
                            hook.argname = muxOut
                            statements += muxCellDecls
                            statements += muxWireDecls

                        } else {
                            let ternary = Node.Cond(
                                shiftIdentifier,
                                previousOutput,
                                hook.argname
                            )
                            hook.argname = ternary
                        }
                    }

                    if portnameStr == dffinfo.q {
                        previousOutput = hook.argname
                    }
                }

                internalOrder.append(
                    ChainRegister(
                        name: String(describing: instance.name),
                        kind: .dff
                    )
                )

            } else if let blackboxModule = blackboxModules[moduleName] {
                // MARK: Isolating hard blocks

                print("Chaining blackbox module '\(blackboxModule.name)'…")
                for hook in instance.portlist {
                    // Note that `hook.argname` is actually an expression
                    let portInfo = blackboxModule.portsByName["\(hook.portname)"]!

                    if ignoredInputs.contains(portInfo.name) {
                        // Leave it alone
                        continue
                    }

                    let wireNameOriginal = "\\\(instanceName).\(portInfo.name).original"
                    let wireNameMultiplexed = "\\\(instanceName).\(portInfo.name).multiplexed"
                    let width = Node.Width(Node.IntConst(portInfo.from), Node.IntConst(portInfo.to))
                    let wiresDecl = Node.Decl([Node.Wire(wireNameOriginal, width: width), Node.Wire(wireNameMultiplexed, width: width)])
                    statements.append(wiresDecl)

                    var kind: ChainRegister.Kind
                    if portInfo.polarity == .input {
                        statements.append(Node.Assign(Node.Identifier(wireNameOriginal), hook.argname))
                        kind = .bypassInput
                    } else if portInfo.polarity == .output {
                        statements.append(Node.Assign(hook.argname, Node.Identifier(wireNameMultiplexed)))
                        hook.argname = Node.Identifier(wireNameOriginal)
                        kind = .bypassOutput
                    } else {
                        throw RuntimeError("Unknown polarity for \(instanceName)'s \(portInfo.name)")
                    }

                    for bit in portInfo.bits {
                        let originalBit = Node.Pointer(Node.Identifier(wireNameOriginal), Node.IntConst(bit))
                        let multiplexedBit = Node.Pointer(Node.Identifier(wireNameMultiplexed), Node.IntConst(bit))
                        let nextOutput = newShiftWire()
                        let decl = bsrCreator.create(
                            group: instanceName,
                            din: originalBit,
                            dout: multiplexedBit,
                            sin: "\(previousOutput)",
                            sout: "\(nextOutput)",
                            input: portInfo.polarity != .input // If it's an input to the macro, it's an output of the circuit we're stitching a scan-chain for
                        )
                        previousOutput = nextOutput
                        statements.append(decl)
                    }
                    internalOrder.append(
                        ChainRegister(
                            name: "\(instanceName).\(portInfo.name)",
                            kind: kind,
                            width: portInfo.width
                        )
                    )
                }
            }

            if let invClock = invClockName, moduleName == invClock {
                for hook in instance.portlist {
                    if String(describing: hook.argname) == clockName {
                        invClkSourceId = Node.Identifier(invClkSourceName)
                        hook.argname = invClkSourceId!
                    }
                }
            }
        }

        statements.append(itemDeclaration)
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
    statements.append(clkSourceAssignment)

    if let invClkId = invClkSourceId {
        let invClockCond = Node.Cond(
            Node.Identifier(testName),
            Node.Unot(Node.Identifier(tckName)),
            Node.Identifier(clockName)
        )

        let invClockAssignment = Node.Assign(
            Node.Lvalue(invClkId),
            Node.Rvalue(invClockCond)
        )
        statements.append(invClockAssignment)
    }

    module.definition.items = Python.tuple(statements)
    module.definition.name = Python.str(alteredName)

    return internalOrder
}

func chainTop(
    Node: PythonObject,
    sclConfig _: SCLConfiguration,
    module: Module,
    blackboxModules _: OrderedDictionary<String, Module>,
    bsrCreator: BoundaryScanRegisterCreator,
    clockName: String,
    resetName: String,
    resetActive _: Simulator.Active,
    shiftName: String,
    inputName: String,
    outputName: String,
    testName: String,
    tckName: String,
    invClockName _: String?,
    ignoredInputs: Set<String>,
    internalOrder: [ChainRegister]
) throws -> (supermodel: PythonObject, order: [ChainRegister]) {
    var order: [ChainRegister] = []
    let ports = Python.list(module.definition.portlist.ports)

    var statements: [PythonObject] = []
    statements.append(Node.Input(inputName))
    statements.append(Node.Output(outputName))
    statements.append(Node.Input(resetName))
    statements.append(Node.Input(shiftName))
    statements.append(Node.Input(tckName))
    statements.append(Node.Input(testName))
    statements.append(Node.Input(clockName))

    let portArguments = Python.list()

    var counter = 0
    let newShiftWire = {
        () in
        let name = "__chain_\(counter)__"
        counter += 1
        statements.append(Node.Decl([Node.Wire(name)]))
        return Node.Identifier(name)
    }
    var previousOutput = newShiftWire()

    let initialAssignment = Node.Assign(
        Node.Lvalue(previousOutput),
        Node.Rvalue(Node.Identifier(inputName))
    )
    statements.append(initialAssignment)

    for input in module.inputs {
        let inputStatement = Node.Input(input.name)

        if input.name != clockName, input.name != resetName {
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
        if input.width == 1 {
            let nextOutput = newShiftWire()
            let decl = bsrCreator.create(
                group: "",
                din: Node.Identifier(input.name),
                dout: Node.Identifier(doutName),
                sin: "\(previousOutput)",
                sout: "\(nextOutput)",
                input: true
            )
            statements.append(decl)
            previousOutput = nextOutput

        } else {
            for bit in input.bits {
                let nextOutput = newShiftWire()
                let decl = bsrCreator.create(
                    group: "",
                    din: Node.Pointer(Node.Identifier(input.name), Node.IntConst(bit)),
                    dout: Node.Pointer(Node.Identifier(doutName), Node.IntConst(bit)),
                    sin: "\(previousOutput)",
                    sout: "\(nextOutput)",
                    input: true
                )
                statements.append(decl)
                previousOutput = nextOutput
            }
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
        Node.Identifier(shiftName)
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
        previousOutput
    ))

    let nextOutput = newShiftWire()
    portArguments.append(Node.PortArg(
        outputName,
        nextOutput
    ))

    order += internalOrder
    previousOutput = nextOutput

    for output in module.outputs {
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

        if output.width == 1 {
            let nextOutput = newShiftWire()
            let decl = bsrCreator.create(
                group: "",
                din: Node.Identifier(dinName),
                dout: Node.Identifier(output.name),
                sin: "\(previousOutput)",
                sout: "\(nextOutput)",
                input: false
            )
            statements.append(decl)
            previousOutput = nextOutput
        } else {
            for bit in output.bits {
                let nextOutput = newShiftWire()
                let decl = bsrCreator.create(
                    group: "",
                    din: Node.Pointer(Node.Identifier(dinName), Node.IntConst(bit)),
                    dout: Node.Pointer(Node.Identifier(output.name), Node.IntConst(bit)),
                    sin: "\(previousOutput)",
                    sout: "\(nextOutput)",
                    input: false
                )
                statements.append(decl)
                previousOutput = nextOutput
            }
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
        module.definition.name,
        "__uuf__",
        Python.tuple(portArguments),
        Python.tuple()
    )

    statements.append(Node.InstanceList(
        module.definition.name,
        Python.tuple(),
        Python.tuple([submoduleInstance])
    ))

    let boundaryAssignment = Node.Assign(
        Node.Lvalue(Node.Identifier(outputName)),
        Node.Rvalue(previousOutput)
    )
    statements.append(boundaryAssignment)

    let supermodel = Node.ModuleDef(
        module.name,
        Python.None,
        Node.Portlist(Python.tuple(ports)),
        Python.tuple(statements)
    )
    print("Boundary scan cells successfully chained. Length: ", order.reduce(0) { $0 + $1.width } - internalOrder.reduce(0) { $0 + $1.width })

    return (supermodel, order)
}

func scanChainCreate(arguments: [String]) -> Int32 {
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

    let ignored = StringOption(
        shortFlag: "i",
        longFlag: "ignoring",
        helpMessage: "Inputs to ignore on both the top level design and all black-boxed macros. Comma-delimited."
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
        helpMessage: "Clock signal to add to --ignoring and use in simulation. (Required.)."
    )
    cli.addOptions(clockOpt)

    let invClock = StringOption(
        longFlag: "invClock",
        helpMessage: "Inverted clk tree source cell name. (Default: none)"
    )
    cli.addOptions(invClock)

    let resetOpt = StringOption(
        longFlag: "reset",
        helpMessage: "Reset signal to add to --ignoring and use in simulation. (Required.)"
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
        helpMessage: "Liberty file. (Required.)"
    )
    cli.addOptions(liberty)

    let sclConfigOpt = StringOption(
        shortFlag: "s",
        longFlag: "sclConfig",
        helpMessage: "Path for the YAML SCL config file. Recommended."
    )
    cli.addOptions(sclConfigOpt)

    let dffOpt = StringOption(
        shortFlag: "d",
        longFlag: "dff",
        helpMessage: "Optional override for the DFF names from the PDK config. Comma-delimited. "
    )
    cli.addOptions(dffOpt)

    let blackboxOpt = StringOption(
        longFlag: "blackbox",
        helpMessage: "Blackbox module names. Comma-delimited. (Default: none)"
    )
    cli.addOptions(blackboxOpt)

    let blackboxModelOpt = StringOption(
        longFlag: "blackboxModel",
        helpMessage: "Files containing definitions for blackbox models. Comma-delimited. (Default: none)"
    )
    cli.addOptions(blackboxModelOpt)

    let defs = StringOption(
        longFlag: "define",
        helpMessage: "define statements to include during simulations.  Comma-delimited. (Default: none)"
    )
    cli.addOptions(defs)

    let include = StringOption(
        longFlag: "inc",
        helpMessage: "Extra verilog models to include during simulations. Comma-delimited. (Default: none)"
    )
    cli.addOptions(include)

    let skipSynth = BoolOption(
        longFlag: "skipSynth",
        helpMessage: "Skip Re-synthesizing the chained netlist. (Default: none)"
    )
    cli.addOptions(skipSynth)

    var names: [String: (default: String, option: StringOption)] = [:]

    for (name, value) in [
        ("sin", "Scan-chain serial data in"),
        ("sout", "Scan-chain serial data out"),
        ("mode", "Input/Output scan-cell mode"),
        ("shift", "Input/Output scan-cell shift"),
        ("clockDR", "Input/Output scan-cell clock DR"),
        ("update", "Input/Output scan-cell update"),
        ("test", "test mode enable"),
        ("tck", "test clock"),
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
        Stderr.print(error)
        Stderr.print("Invoke fault chain --help for more info.")
        return EX_USAGE
    }

    if help.value {
        cli.printUsage()
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        Stderr.print("Invalid argument count: (\(args.count)/\(1))")
        Stderr.print("Invoke fault chain --help for more info.")
        return EX_USAGE
    }

    let fileManager = FileManager()
    let file = args[0]
    if !fileManager.fileExists(atPath: file) {
        Stderr.print("File '\(file)' not found.")
        return EX_NOINPUT
    }

    guard let clockName = clockOpt.value else {
        Stderr.print("Option --clock is required.")
        Stderr.print("Invoke fault chain --help for more info.")
        return EX_USAGE
    }

    guard let resetName = resetOpt.value else {
        Stderr.print("Option --reset is required.")
        Stderr.print("Invoke fault chain --help for more info.")
        return EX_USAGE
    }

    guard let libertyFile = liberty.value else {
        Stderr.print("Option --liberty is required.")
        Stderr.print("Invoke fault chain --help for more info.")
        return EX_USAGE
    }

    var sclConfig = SCLConfiguration(dffMatches: [DFFMatch(name: "DFFSR,DFFNEGX1,DFFPOSX1", clk: "CLK", d: "D", q: "Q")])
    if let sclConfigPath = sclConfigOpt.value {
        guard let sclConfigYML = File.read(sclConfigPath) else {
            Stderr.print("File not found: \(sclConfigPath)")
            return EX_NOINPUT
        }
        let decoder = YAMLDecoder()
        do {
            sclConfig = try decoder.decode(SCLConfiguration.self, from: sclConfigYML)
        } catch {
            Stderr.print("Invalid YAML file \(sclConfigPath):  \(error).")
            return EX_DATAERR
        }
    }
    if let dffOverride = dffOpt.value {
        sclConfig.dffMatches.last!.name = dffOverride
    }

    if !fileManager.fileExists(atPath: libertyFile) {
        Stderr.print("Liberty file '\(libertyFile)' not found.")
        return EX_NOINPUT
    }

    if !libertyFile.hasSuffix(".lib") {
        Stderr.print(
            "Warning: Liberty file provided does not end with .lib."
        )
    }

    if let modelTest = verifyOpt.value {
        if !fileManager.fileExists(atPath: modelTest) {
            Stderr.print("Cell model file '\(modelTest)' not found.")
            return EX_NOINPUT
        }
        if !modelTest.hasSuffix(".v"), !modelTest.hasSuffix(".sv") {
            Stderr.print(
                "Warning: Cell model file provided does not end with .v or .sv.\n"
            )
        }
    }

    let output = filePath.value ?? "\(file).chained.v"
    let intermediate = output + ".intermediate.v"

    var ignoredInputs
        = Set<String>(ignored.value?.components(separatedBy: ",") ?? [])
    let defines
        = Set<String>(defs.value?.components(separatedBy: ",") ?? [])

    ignoredInputs.insert(clockName)
    ignoredInputs.insert(resetName)

    let includeFiles
        = Set<String>(include.value?.components(separatedBy: ",").filter { $0 != "" } ?? [])

    // MARK: Importing Python and Pyverilog

    let parse = Python.import("pyverilog.vparser.parser").parse

    let Node = Python.import("pyverilog.vparser.ast")

    let Generator =
        Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()

    // MARK: Parse

    let modules = try! Module.getModules(in: [file])
    guard let module = modules.values.first else {
        Stderr.print("No modules found in file.")
        return EX_DATAERR
    }

    let blackboxModuleNames = Set<String>((blackboxOpt.value?.components(separatedBy: ",")) ?? [])
    let blackboxModels = blackboxModelOpt.value?.components(separatedBy: ",") ?? []
    let blackboxModules = try! Module.getModules(in: blackboxModels, filter: blackboxModuleNames)

    do {
        let shiftName = names["shift"]!.option.value ?? names["shift"]!.default
        let inputName = names["sin"]!.option.value ?? names["sin"]!.default
        let outputName = names["sout"]!.option.value ?? names["sout"]!.default
        let testName = names["test"]!.option.value ?? names["test"]!.default
        let tckName = names["tck"]!.option.value ?? names["tck"]!.default

        let bsrCreator = BoundaryScanRegisterCreator(
            name: "BoundaryScanRegister",
            clock: tckName,
            reset: resetName,
            resetActive: resetActiveLow.value ? .low : .high,
            testing: testName,
            shift: shiftName,
            using: Node
        )

        let internalOrder = try chainInternal(
            Node: Node,
            sclConfig: sclConfig,
            module: module,
            blackboxModules: blackboxModules,
            bsrCreator: bsrCreator,
            clockName: clockName,
            resetName: resetName,
            resetActive: resetActiveLow.value ? .low : .high,
            shiftName: shiftName,
            inputName: inputName,
            outputName: outputName,
            testName: testName,
            tckName: tckName,
            invClockName: invClock.value,
            ignoredInputs: ignoredInputs
        )
        let internalCount = internalOrder.reduce(0) { $0 + $1.width }
        if internalCount == 0 {
            print("Warning: No internal scan elements found. Are your DFFs configured properly?")
        } else {
            print("Internal scan chain successfuly constructed. Length: ", internalCount)
        }

        let (supermodel, finalOrder) = try chainTop(
            Node: Node,
            sclConfig: sclConfig,
            module: module,
            blackboxModules: blackboxModules,
            bsrCreator: bsrCreator,
            clockName: clockName,
            resetName: resetName,
            resetActive: resetActiveLow.value ? .low : .high,
            shiftName: shiftName,
            inputName: inputName,
            outputName: outputName,
            testName: testName,
            tckName: tckName,
            invClockName: invClock.value,
            ignoredInputs: ignoredInputs,
            internalOrder: internalOrder
        )
        let finalCount = finalOrder.reduce(0) { $0 + $1.width }

        let finalAst = parse([bsrCreator.inputDefinition + bsrCreator.outputDefinition])[0]
        let finalDefinitions = [PythonObject](finalAst[dynamicMember: "description"].definitions)! + [module.definition, supermodel]
        finalAst[dynamicMember: "description"].definitions = Python.tuple(finalDefinitions)

        try File.open(intermediate, mode: .write) {
            try $0.print(Generator.visit(finalAst))
        }

        print("Total scan-chain length: ", finalCount)

        let metadata = ChainMetadata(
            boundaryCount: finalCount - internalCount,
            internalCount: internalCount,
            order: finalOrder,
            shift: shiftName,
            sin: inputName,
            sout: outputName
        )
        guard let metadataString = metadata.toJSON() else {
            Stderr.print("Could not generate metadata string.")
            return EX_SOFTWARE
        }

        let netlist: String = {
            if !skipSynth.value {
                let script = Synthesis.script(
                    for: module.name,
                    in: [intermediate],
                    liberty: libertyFile,
                    blackboxing: blackboxModels,
                    output: output
                )

                // MARK: Yosys

                print("Resynthesizing with yosys…")
                let result = "echo '\(script)' | '\(yosysExecutable)' > /dev/null".sh()

                if result != EX_OK {
                    Stderr.print("A yosys error has occurred.")
                    exit(EX_DATAERR)
                }
                return output
            } else {
                return intermediate
            }
        }()

        guard let content = File.read(netlist) else {
            throw "Could not re-read created file."
        }

        try File.open(netlist, mode: .write) {
            try $0.print(String.boilerplate)
            try $0.print("/* FAULT METADATA: '\(metadataString)' END FAULT METADATA */")
            try $0.print(content)
        }

        // MARK: Verification

        if let model = verifyOpt.value {
            let models = [model] + Array(includeFiles) + Array(blackboxModels)

            print("Verifying scan chain integrity…")
            let ast = parse([netlist])[0]
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
                verifying: module.name,
                in: netlist,
                with: models,
                ports: ports,
                inputs: inputs,
                outputs: outputs,
                chainLength: finalOrder.reduce(0) { $0 + $1.width },
                clock: clockName,
                tck: tckName,
                reset: resetName,
                sin: inputName,
                sout: outputName,
                resetActive: resetActiveLow.value ? .low : .high,
                shift: shiftName,
                test: testName,
                output: netlist + ".tb.sv",
                defines: defines,
                using: iverilogExecutable,
                with: vvpExecutable
            )
            if verified {
                print("Scan chain verified successfully.")
            } else {
                print("Scan chain verification failed.")
                print("・Ensure that clock and reset signals, if they exist are passed as such to the program.")
                if !resetActiveLow.value {
                    print("・Ensure that the reset is active high- pass --activeLow for activeLow.")
                }
                if internalOrder.count == 0 {
                    print("・Ensure that D flip-flop cell names match those either in the defaults, the PDK config, or the overrides.")
                }
                print("・Ensure that there are no other asynchronous resets anywhere in the circuit.")
                return EX_DATAERR
            }
        }
        print("Done.")

    } catch {
        Stderr.print("Internal software error: \(error)")
        return EX_SOFTWARE
    }
    return EX_OK
}
