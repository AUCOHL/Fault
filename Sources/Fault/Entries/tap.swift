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

import ArgumentParser
import BigInt
import CoreFoundation
import Defile
import Foundation
import PythonKit

extension Fault {
  struct Tap: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Add a JTAG TAP port and controller to a netlist with a scan-chain."
    )

    @Option(name: [.short, .long], help: "Path to the output file.")
    var output: String?

    @Option(
      name: [.short, .long, .customLong("cellModel")],
      help: "Verify JTAG port using given cell model."
    )
    var cellModel: String?

    @OptionGroup
    var bypass: BypassOptions

    @Option(name: [.short, .long], help: "Liberty file. (Required.)")
    var liberty: String

    @Option(name: [.short, .long], help: ".bin file for test vectors.")
    var testVectors: String?

    @Option(
      name: [.short, .long],
      help: ".bin file for golden output. Required iff testVectors is provided."
    )
    var goldenOutput: String?

    @Option(
      name: [.customShort("b"), .customLong("blackbox")],
      help: "Blackbox module names. Specify multiple times to specify multiple modules."
    )
    var blackbox: [String] = []

    @Option(
      name: [.customShort("B"), .long, .customLong("blackboxModel")],
      help: "Blackbox model verilog files. Specify multiple times to specify multiple models."
    )
    var blackboxModels: [String] = []

    @Option(
      name: [.customShort("D"), .customLong("define")],
      help:
        "`define statements to include during simulations. Specify multiple times to specify multiple defines."
    )
    var defines: [String] = []

    @Option(
      name: [.customShort("I"), .customLong("inc"), .customLong("include")],
      help: "Extra verilog models to include during simulations. (Default: none)"
    )
    var includes: [String] = []

    @Flag(name: [.long], help: "Skip re-synthesizing the chained netlist.")
    var skipSynth: Bool = false

    // Scan chain signals with default names
    @Option(name: .long, help: "Name for scan-chain serial data in signal.")
    var sin: String = "sin"

    @Option(name: .long, help: "Name for scan-chain serial data out signal.")
    var sout: String = "sout"

    @Option(name: .long, help: "Name for scan-chain shift enable signal.")
    var shift: String = "shift"

    @Option(name: .long, help: "Name for scan-chain test enable signal.")
    var test: String = "test"

    @Option(name: .long, help: "Name for JTAG test mode select signal.")
    var tms: String = "tms"

    @Option(name: .long, help: "Name for JTAG test clock signal.")
    var tck: String = "tck"

    @Option(name: .long, help: "Name for JTAG test data input signal.")
    var tdi: String = "tdi"

    @Option(name: .long, help: "Name for JTAG test data output signal.")
    var tdo: String = "tdo"

    @Option(name: .long, help: "Name for TDO Enable pad (active low) signal.")
    var tdoEnable: String = "tdo_paden_o"

    @Option(name: .long, help: "Name for JTAG test reset (active low) signal.")
    var trst: String = "trst"

    @Argument
    var file: String

    mutating func run() throws {
      let fileManager = FileManager()
      if !fileManager.fileExists(atPath: file) {
        throw ValidationError("File '\(file)' not found.")
      }

      let (_, boundaryCount, internalCount) = ChainMetadata.extract(file: file)

      let defines = Set<String>(defines)

      if !fileManager.fileExists(atPath: liberty) {
        throw ValidationError("Liberty file '\(liberty)' not found.")
      }

      if !liberty.hasSuffix(".lib") {
        Stderr.print(
          "Warning: Liberty file provided does not end with .lib."
        )
      }

      if let modelTest = cellModel {
        if !fileManager.fileExists(atPath: modelTest) {
          throw ValidationError("Cell model file '\(modelTest)' not found.")
        }
        if !modelTest.hasSuffix(".v"), !modelTest.hasSuffix(".sv") {
          Stderr.print(
            "Warning: Cell model file provided does not end with .v or .sv."
          )
        }
      }

      if let tvTest = testVectors {
        if !fileManager.fileExists(atPath: tvTest) {
          throw ValidationError("Test vectors file '\(tvTest)' not found.")
        }
        if !tvTest.hasSuffix(".bin") {
          Stderr.print(
            "Warning: Test vectors file provided does not end with .bin."
          )
        }
        guard goldenOutput != nil else {
          throw ValidationError("Using goldenOutput (-g) option is required '\(tvTest)'.")
        }
      }

      let output = output ?? file.replacingExtension(".chained.v", with: ".jtag.v")  // "\(file).jtag.v"
      let intermediate = output.replacingExtension(".jtag.v", with: ".jtag_intermediate.v")

      // MARK: Importing Python and Pyverilog

      let parse = Python.import("pyverilog.vparser.parser").parse

      let Node = Python.import("pyverilog.vparser.ast")

      let Generator =
        Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()

      // MARK: Parse

      let ast = parse([file])[0]
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

      // MARK: Internal signals

      print("Creating top module…")
      let definitionName = String(describing: definition.name)
      let alteredName = "__DESIGN__UNDER__TEST__"

      do {
        let (_, inputs, outputs) = try Port.extract(from: definition)
        definition.name = Python.str(alteredName)
        let ports = Python.list(definition.portlist.ports)

        let chainPorts: [String] = [
          sin,
          sout,
          shift,
          tck,
          test,
        ]
        let topModulePorts = Python.list(
          ports.filter {
            !chainPorts.contains(String($0.name)!)
          })

        topModulePorts.append(
          Node.Port(
            tms, Python.None, Python.None, Python.None
          ))
        topModulePorts.append(
          Node.Port(
            tck, Python.None, Python.None, Python.None
          ))
        topModulePorts.append(
          Node.Port(
            tdi, Python.None, Python.None, Python.None
          ))
        topModulePorts.append(
          Node.Port(
            tdo, Python.None, Python.None, Python.None
          ))
        topModulePorts.append(
          Node.Port(
            trst, Python.None, Python.None, Python.None
          ))
        topModulePorts.append(
          Node.Port(
            tdoEnable, Python.None, Python.None, Python.None
          ))

        let statements = Python.list()
        statements.append(Node.Input(tms))
        statements.append(Node.Input(tck))
        statements.append(Node.Input(tdi))
        statements.append(Node.Output(tdo))
        statements.append(Node.Output(tdoEnable))
        statements.append(Node.Input(trst))

        let portArguments = Python.list()
        for input in inputs {
          if !chainPorts.contains(input.name) {
            let inputStatement = Node.Input(input.name)
            portArguments.append(
              Node.PortArg(
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
          } else {
            let portIdentifier = input.name
            portArguments.append(
              Node.PortArg(
                input.name,
                Node.Identifier(portIdentifier)
              ))
          }
        }

        for output in outputs {
          if !chainPorts.contains(output.name) {
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
          portArguments.append(
            Node.PortArg(
              output.name,
              Node.Identifier(output.name)
            ))
        }

        // MARK: tap module

        print("Stitching tap port…")
        let tapInfo = TapInfo.default

        let tapCreator = TapCreator(
          name: "tap_wrapper",
          using: Node
        )
        let tapModule = tapCreator.create(
          tapInfo: tapInfo,
          tms: tms,
          tck: tck,
          tdi: tdi,
          tdo: tdo,
          tdoEnable_n: tdoEnable,
          trst: trst,
          sin: sin,
          sout: sout,
          shift: shift,
          test: test
        )

        statements.extend(tapModule.wires)
        statements.append(tapModule.tapModule)

        let submoduleInstance = Node.Instance(
          alteredName,
          "__dut__",
          Python.tuple(portArguments),
          Python.tuple()
        )

        statements.append(
          Node.InstanceList(
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

        } catch {}

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

        let _ = Synthesis.script(
          for: definitionName,
          in: [intermediate],
          liberty: liberty,
          blackboxing: blackboxModels,
          output: output
        )

        let netlist: String = {
          if !skipSynth {
            let script = Synthesis.script(
              for: definitionName,
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

        guard let model = cellModel else {
          print("Done.")
          return
        }

        guard let content = File.read(netlist) else {
          throw "Could not re-read created file."
        }

        try File.open(netlist, mode: .write) {
          try $0.print(String.boilerplate)
          try $0.print(content)
        }

        // MARK: Verification

        let models = [model] + includes + blackboxModels

        print("Verifying tap port integrity…")
        let ast = parse([netlist])[0]
        let description = ast[dynamicMember: "description"]
        var definitionOptional: PythonObject?
        for definition in description.definitions {
          let type = Python.type(definition).__name__
          if type == "ModuleDef" {
            definitionOptional = definition
          }
        }
        guard let definition = definitionOptional else {
          Stderr.print("No module found.")
          Foundation.exit(EX_DATAERR)
        }
        let (myPorts, myInputs, myOutputs) = try Port.extract(from: definition)
        let verified = try Simulator.simulate(
          verifying: definitionName,
          in: netlist,  // DEBUG
          with: models,
          ports: myPorts,
          inputs: myInputs,
          outputs: myOutputs,
          chainLength: boundaryCount + internalCount,
          clock: bypass.clock,
          reset: bypass.reset.name,
          resetActive: bypass.reset.active,
          tms: tms,
          tdi: tdi,
          tck: tck,
          tdo: tdo,
          trst: trst,
          output: netlist + ".tb.sv",
          defines: defines,
          using: iverilogExecutable,
          with: vvpExecutable
        )
        print("Done.")
        if verified {
          print("Tap port verified successfully.")
        } else {
          print("Tap port verification failed.")
          print(
            "・Ensure that clock and reset signals, if they exist are passed as such to the program."
          )
          if bypass.reset.active == .high {
            print("・Ensure that the reset is active high- pass --activeLow for activeLow.")
          }
          print("・Ensure that there are no other asynchronous resets anywhere in the circuit.")
        }

        // MARK: Test bench

        if let tvFile = testVectors {
          print("Generating testbench for test vectors…")
          let (vectorCount, vectorLength) = binMetadata.extract(file: tvFile)
          let (_, outputLength) = binMetadata.extract(file: goldenOutput!)
          let testbecnh = netlist + ".tv" + ".tb.sv"
          let verified = try Simulator.simulate(
            verifying: definitionName,
            in: netlist,
            with: models,
            ports: myPorts,
            inputs: myInputs,
            bypassingWithBehavior: bypass.simulationValues,
            outputs: myOutputs,
            clock: bypass.clock,
            reset: bypass.reset.name,
            resetActive: bypass.reset.active,
            tms: tms,
            tdi: tdi,
            tck: tck,
            tdo: tdo,
            trst: trst,
            output: testbecnh,
            chainLength: internalCount + boundaryCount,
            vecbinFile: testVectors!,
            outbinFile: goldenOutput!,
            vectorCount: vectorCount,
            vectorLength: vectorLength,
            outputLength: outputLength,
            defines: defines,
            using: iverilogExecutable,
            with: vvpExecutable
          )
          if verified {
            print("Test vectors verified successfully.")
          } else {
            print("Test vector simulation failed.")
            if bypass.reset.active == .high {  // default is ignored inputs are held high
              print(
                "・The reset is assumed active-high and thus held low. Pass --activeLow if reset is active low."
              )
            }
            Foundation.exit(EX_DATAERR)
          }
        }
      } catch {
        Stderr.print("Internal software error: \(error)")
        Foundation.exit(EX_SOFTWARE)
      }
    }
  }
}
