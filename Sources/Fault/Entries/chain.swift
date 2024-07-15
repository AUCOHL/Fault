// Copyright (C) 2019-2024 The American University in Cairo
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
import ArgumentParser
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
    bypass: inout BypassOptions,
    shiftName: String,
    inputName: String,
    outputName: String,
    testName: String,
    tckName: String,
    invClockName: String?
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
    let newShiftWire: () -> PythonObject = { // Type annotation required in Swift 5.4
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
                        if String(describing: hook.argname) == bypass.clock {
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

                    if bypass.bypassedInputs.contains(portInfo.name) {
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
                    if String(describing: hook.argname) == bypass.clock {
                        invClkSourceId = Node.Identifier(invClkSourceName)
                        hook.argname = invClkSourceId!
                    }
                }
            }
        }

        statements.append(itemDeclaration)
    }

    if warn {
        print("[Warning]: Detected flip-flops with clock different from \(bypass.clock).")
    }

    let finalAssignment = Node.Assign(
        Node.Lvalue(outputIdentifier),
        Node.Rvalue(previousOutput)
    )
    statements.append(finalAssignment)

    let clockCond = Node.Cond(
        Node.Identifier(testName),
        Node.Identifier(tckName),
        Node.Identifier(bypass.clock)
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
            Node.Identifier(bypass.clock)
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
    bypass: inout BypassOptions,
    shiftName: String,
    inputName: String,
    outputName: String,
    testName: String,
    tckName: String,
    invClockName _: String?,
    internalOrder: [ChainRegister]
) throws -> (supermodel: PythonObject, order: [ChainRegister]) {
    var order: [ChainRegister] = []
    let ports = Python.list(module.definition.portlist.ports)

    var statements: [PythonObject] = []
    statements.append(Node.Input(inputName))
    statements.append(Node.Output(outputName))
    statements.append(Node.Input(bypass.reset.name))
    statements.append(Node.Input(shiftName))
    statements.append(Node.Input(tckName))
    statements.append(Node.Input(testName))
    statements.append(Node.Input(bypass.clock))

    let portArguments = Python.list()

    var counter = 0
    let newShiftWire: () -> PythonObject = { // Type annotation required in Swift 5.4
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

        if input.name != bypass.clock, input.name != bypass.reset.name {
            statements.append(inputStatement)
        }
        if bypass.bypassedInputs.contains(input.name) {
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


extension Fault {
    struct Chain: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Manipulate a netlist to create a scan chain, and resynthesize."
        )
        
        @Option(name: [.short, .long], help: "Path to the output file. (Default: input + .chained.v)")
        var output: String?
        
        @Option(name: [.short, .long, .customLong("cellModel")], help: "Verify scan chain using given cell model.")
        var cellModel: String?
        
        @Option(name: [.long], help: "Inverted clk tree source cell name. (Default: none)")
        var invClock: String?
        
        @Option(name: [.short, .long], help: "Liberty file. (Required.)")
        var liberty: String
        
        @OptionGroup
        var bypass: BypassOptions
        
        @Option(name: [.short, .long, .customLong("sclConfig")], help: "Path for the YAML SCL config file. Recommended.")
        var sclConfig: String?
        
        @Option(name: [.short, .long], help: "Optional override for the DFF names from the PDK config. Comma-delimited.")
        var dff: String?
        
        @Option(name: [.customShort("b"), .customLong("blackbox")], help: "Blackbox module names. Comma-delimited. (Default: none)")
        var blackbox: [String] = []
        
        @Option(name: [.customShort("B"), .long, .customLong("blackboxModel")], help: "Files containing definitions for blackbox models. Comma-delimited. (Default: none)")
        var blackboxModels: [String] = []
        
        @Option(name: [.customShort("D"), .customLong("define")], help: "define statements to include during simulations. Comma-delimited. (Default: none)")
        var defines: [String] = []
        
        @Option(name: .long, help: "Extra verilog models to include during simulations. Comma-delimited. (Default: none)")
        var inc: String?
        
        @Flag(name: .long, help: "Skip Re-synthesizing the chained netlist. (Default: none)")
        var skipSynth: Bool = false
        
        @Option(name: .long, help: "Name for scan-chain serial data in signal.")
        var sin: String = "sin"

        @Option(name: .long, help: "Name for scan-chain serial data out signal.")
        var sout: String = "sout"

        @Option(name: .long, help: "Name for scan-chain shift enable signal.")
        var shift: String = "shift"

        @Option(name: .long, help: "Name for scan-chain test enable signal.")
        var test: String = "test"

        @Option(name: .long, help: "Name for JTAG test clock signal.")
        var tck: String = "tck"
        
        @Argument
        var file: String
        
        mutating func run() throws {
            let fileManager = FileManager()

            // Check if input file exists
            guard fileManager.fileExists(atPath: file) else {
                throw ValidationError("File '\(file)' not found.")
            }

            // Required options validation
            var sclConfig = SCLConfiguration(dffMatches: [DFFMatch(name: "DFFSR,DFFNEGX1,DFFPOSX1", clk: "CLK", d: "D", q: "Q")])
            if let sclConfigPath = self.sclConfig {
                guard let sclConfigYML = File.read(sclConfigPath) else {
                    throw ValidationError("File not found: \(sclConfigPath)")
                }
                let decoder = YAMLDecoder()
                sclConfig = try decoder.decode(SCLConfiguration.self, from: sclConfigYML)
            }

            if let dffOverride = dff {
                sclConfig.dffMatches.last!.name = dffOverride
            }

            if !fileManager.fileExists(atPath: liberty) {
                throw ValidationError("Liberty file '\(liberty)' not found.")
            }

            if !liberty.hasSuffix(".lib") {
                print("Warning: Liberty file provided does not end with .lib.")
            }

            let output = output ?? file.replacingExtension(".nl.v", with: ".chained.v")
            let intermediate = output.replacingExtension(".chained.v", with: ".chain-intermediate.v")

            let includeFiles = Set<String>(inc?.components(separatedBy: ",").filter { !$0.isEmpty } ?? [])

            // MARK: Importing Python and Pyverilog

            let parse = Python.import("pyverilog.vparser.parser").parse
            let Node = Python.import("pyverilog.vparser.ast")
            let Generator = Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()

            // MARK: Parse

            let modules = try! Module.getModules(in: [file])
            guard let module = modules.values.first else {
                throw ValidationError("No modules found in file.")
            }

            let blackboxModules = try! Module.getModules(in: blackboxModels, filter: Set(blackbox))

            let bsrCreator = BoundaryScanRegisterCreator(
                name: "BoundaryScanRegister",
                clock: tck,
                reset: bypass.reset.name,
                resetActive: bypass.reset.active,
                testing: test,
                shift: shift,
                using: Node
            )

            let internalOrder = try chainInternal(
                Node: Node,
                sclConfig: sclConfig,
                module: module,
                blackboxModules: blackboxModules,
                bsrCreator: bsrCreator,
                bypass: &bypass,
                shiftName: shift,
                inputName: sin,
                outputName: sout,
                testName: test,
                tckName: tck,
                invClockName: invClock
            )

            let internalCount = internalOrder.reduce(0) { $0 + $1.width }
            if internalCount == 0 {
                print("Warning: No internal scan elements found. Are your DFFs configured properly?")
            } else {
                print("Internal scan chain successfully constructed. Length: \(internalCount)")
            }

            let (supermodel, finalOrder) = try chainTop(
                Node: Node,
                sclConfig: sclConfig,
                module: module,
                blackboxModules: blackboxModules,
                bsrCreator: bsrCreator,
                bypass: &bypass,
                shiftName: shift,
                inputName: sin,
                outputName: sout,
                testName: test,
                tckName: tck,
                invClockName: invClock,
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
                shift: shift,
                sin: sin,
                sout: sout
            )
            guard let metadataString = metadata.toJSON() else {
                Stderr.print("Could not generate metadata string.")
                Foundation.exit(EX_SOFTWARE)
            }

            let netlist: String = {
                if !skipSynth {
                    let script = Synthesis.script(
                        for: module.name,
                        in: [intermediate],
                        liberty: liberty,
                        blackboxing: blackboxModels,
                        output: output
                    )

                    // MARK: Yosys

                    print("Resynthesizing with yosys…")
                    let result = "echo '\(script)' | '\(yosysExecutable)' > /dev/null".sh()

                    if result != EX_OK {
                        Stderr.print("A yosys error has occurred.")
                        Foundation.exit(EX_DATAERR)
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

            if let model = cellModel {
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
                    Foundation.exit(EX_DATAERR)
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
                    clock: bypass.clock,
                    tck: tck,
                    reset: bypass.reset.name,
                    sin: sin,
                    sout: sout,
                    resetActive: bypass.reset.active,
                    shift: shift,
                    test: test,
                    output: netlist + ".tb.sv",
                    defines: Set(defines),
                    using: iverilogExecutable,
                    with: vvpExecutable
                )
                if verified {
                    print("Scan chain verified successfully.")
                } else {
                    print("Scan chain verification failed.")
                    print("・Ensure that clock and reset signals, if they exist are passed as such to the program.")
                    if !bypass.resetActiveLow {
                        print("・Ensure that the reset is active high- pass --activeLow for activeLow.")
                    }
                    if internalOrder.count == 0 {
                        print("・Ensure that D flip-flop cell names match those either in the defaults, the PDK config, or the overrides.")
                    }
                    print("・Ensure that there are no other asynchronous resets anywhere in the circuit.")
                    Foundation.exit(EX_DATAERR)
                }
            }
            print("Done.")

        }
    }
}
