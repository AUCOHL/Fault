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

import CommandLineKit
import Defile
import Foundation
import PythonKit
import Yams

func cut(arguments: [String]) -> Int32 {
    let cli = CommandLineKit.CommandLine(arguments: arguments)

    let help = BoolOption(
        shortFlag: "h",
        longFlag: "help",
        helpMessage: "Prints this message and exits."
    )
    cli.addOptions(help)

    let dffOpt = StringOption(
        shortFlag: "d",
        longFlag: "dff",
        helpMessage: "Override for flip-flop cell names. Comma-delimited. (Default: DFF)."
    )
    cli.addOptions(dffOpt)

    let sclConfigOpt = StringOption(
        shortFlag: "s",
        longFlag: "sclConfig",
        helpMessage: "Path for the YAML SCL config file. Recommended."
    )
    cli.addOptions(sclConfigOpt)

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

    let ignored = StringOption(
        shortFlag: "i",
        longFlag: "ignoring",
        helpMessage: "Inputs to ignore on black-boxed macros. Comma-delimited."
    )
    cli.addOptions(ignored)

    let filePath = StringOption(
        shortFlag: "o",
        longFlag: "output",
        helpMessage: "Path to the output file. (Default: input + .chained.v)"
    )
    cli.addOptions(filePath)

    do {
        try cli.parse()
    } catch {
        Stderr.print(error)
        Stderr.print("Invoke fault cut --help for more info.")
        return EX_USAGE
    }

    if help.value {
        cli.printUsage()
        return EX_OK
    }

    let args = cli.unparsedArguments
    if args.count != 1 {
        Stderr.print("Invalid argument count: (\(args.count)/\(1))")
        Stderr.print("Invoke fault cut --help for more info.")
        return EX_USAGE
    }

    let fileManager = FileManager()
    let file = args[0]
    if !fileManager.fileExists(atPath: file) {
        Stderr.print("File '\(file)' not found.")
        return EX_NOINPUT
    }

    let output = filePath.value ?? "\(file).cut.v"

    let ignoredInputs = Set<String>(ignored.value?.components(separatedBy: ",") ?? [])

    // MARK: Importing Python and Pyverilog

    let parse = Python.import("pyverilog.vparser.parser").parse

    let Node = Python.import("pyverilog.vparser.ast")

    let Generator =
        Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()

    let blackboxModuleNames = Set<String>((blackboxOpt.value?.components(separatedBy: ",")) ?? [])
    let blackboxModels = blackboxModelOpt.value?.components(separatedBy: ",") ?? []
    let blackboxModules = try! Module.getModules(in: blackboxModels, filter: blackboxModuleNames)

    var definitionOptional: PythonObject?
    let ast = parse([file])[0]
    let description = ast[dynamicMember: "description"]

    for definition in description.definitions {
        let type = Python.type(definition).__name__
        if type == "ModuleDef" {
            definitionOptional = definition
            break
        }
    }

    guard let definition = definitionOptional else {
        Stderr.print("No module found.")
        exit(EX_DATAERR)
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

    do {
        let ports = Python.list(definition.portlist.ports)
        var declarations: [PythonObject] = []
        var items: [PythonObject] = []

        let fnmatch = Python.import("fnmatch")

        for item in definition.items {
            var yank = false

            let type = Python.type(item).__name__
            // Process gates
            if type == "InstanceList" {
                let instance = item.instances[0]
                let moduleName = "\(instance.module)"
                let instanceName = "\(instance.name)"
                if let dffinfo = getMatchingDFFInfo(from: sclConfig.dffMatches, for: moduleName, fnmatch: fnmatch) {
                    yank = true
                    
                    let moduleName = String(describing: instance.name)
                    let outputName = "\\" + moduleName + ".q"

                    let inputIdentifier = Node.Identifier(moduleName)
                    let outputIdentifier = Node.Identifier(outputName)
                    
                    var dArg: PythonObject?
                    var qArg: PythonObject?

                    for hook in instance.portlist {
                        if String(describing: hook.portname) == dffinfo.d {
                            dArg = hook.argname
                        }
                        if String(describing: hook.portname) == dffinfo.q {
                            qArg = hook.argname
                        }
                    }

                    guard let d = dArg, let q = qArg else {
                        Stderr.print(
                            "Cell \(moduleName) missing either a 'D' or 'Q' port."
                        )
                        return EX_DATAERR
                    }

                    ports.append(Node.Port(moduleName, Python.None, Python.None, Python.None))
                    ports.append(Node.Port(outputName, Python.None, Python.None, Python.None))

                    declarations.append(Node.Input(moduleName))
                    declarations.append(Node.Output(outputName))

                    let inputAssignment = Node.Assign(
                        Node.Lvalue(q),
                        Node.Rvalue(inputIdentifier)
                    )
                    let outputAssignment = Node.Assign(
                        Node.Lvalue(outputIdentifier),
                        Node.Rvalue(d)
                    )

                    items.append(inputAssignment)
                    items.append(outputAssignment)

                } else if let blackboxModule = blackboxModules[moduleName] {
                    yank = true

                    for hook in instance.portlist {
                        let portName = String(describing: hook.portname)
                        
                        if ignoredInputs.contains(portName) {
                            continue
                        }
                        
                        let portInfo = blackboxModule.portsByName[portName]!
                        
                        let ioDeclaration: PythonObject
                        let assignStatement: PythonObject
                        var ioName: String = "\\\(instanceName).\(portName)"
                        let width = Node.Width(Node.IntConst(portInfo.from), Node.IntConst(portInfo.to))
                        if portInfo.polarity == .input {
                            // Input to the blackbox module = Output from the circuit, and vice versa
                            ioName += ".q"
                            ioDeclaration = Node.Output(ioName, width)
                            assignStatement = Node.Assign(
                                Node.Lvalue(Node.Identifier(ioName)),
                                Node.Rvalue(hook.argname)
                            )
                        } else {
                            ioDeclaration = Node.Input(ioName, width)
                            assignStatement = Node.Assign(
                                Node.Rvalue(hook.argname),
                                Node.Lvalue(Node.Identifier(ioName))
                            )
                        }
                        items.append(assignStatement)
                        declarations.append(ioDeclaration)
                        ports.append(Node.Port(ioName, Python.None, Python.None, Python.None))
                    }
                }
            }

            if !yank {
                items.append(item)
            }
        }

        if declarations.count == 0 {
            print("[Warning]: Failed to detect any flip-flop cells.")
        }

        definition.portlist.ports = ports
        definition.items = Python.tuple(declarations + items)

        try File.open(output, mode: .write) {
            try $0.print(String.boilerplate)
            try $0.print(Generator.visit(definition))
        }
    } catch {
        Stderr.print("An internal software error has occurred.")
        return EX_SOFTWARE
    }

    return EX_OK
}
