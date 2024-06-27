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

import BigInt
import Collections
import ArgumentParser
import CoreFoundation // Not automatically imported on Linux
import Defile
import Foundation
import PythonKit
import Yams

extension Fault {
    struct Cut: ParsableCommand {
        
        static let configuration = CommandConfiguration(
            abstract: "Cut away D-flipflops, converting them into inputs and outputs. This is a necessary precursor to the ATPG step."
        )
        
        @Option(name: [.short, .long], help: "Override for flip-flop cell names. Comma-delimited. (Default: DFF).")
        var dff: String?
        
        @Option(name: [.short, .long, .customLong("sclConfig")], help: "Path for the YAML SCL config file. Recommended.")
        var sclConfig: String?
        
        @Option(name: [.short, .long], help: "Blackbox module names. Comma-delimited. (Default: none)")
        var blackbox: [String] = []
        
        @Option(name: [.customShort("B"), .long, .customLong("blackboxModel")], help: "Files containing definitions for blackbox models. Comma-delimited. (Default: none)")
        var blackboxModels: [String] = []
        
        @Option(name: [.short, .long], help: "Inputs to ignore on black-boxed macros. Comma-delimited.")
        var ignoring: String?
        
        @Option(name: [.short, .long], help: "Path to the output file. (Default: input + .chained.v)")
        var output: String?
        
        @Argument(help: "The file to process.")
        var file: String
        
        mutating func run() throws {
            let fileManager = FileManager()
            
            guard fileManager.fileExists(atPath: file) else {
                throw ValidationError("File '\(file)' not found.")
            }
            
            let output = self.output ?? "\(file).cut.v"
            
            var ignoredInputs: Set<String> = []
            if let ignoring = ignoring {
                ignoredInputs = Set(ignoring.components(separatedBy: ","))
            }
            
            // MARK: Importing Python and Pyverilog
            
            let parse = Python.import("pyverilog.vparser.parser").parse
            let Node = Python.import("pyverilog.vparser.ast")
            let Generator = Python.import("pyverilog.ast_code_generator.codegen").ASTCodeGenerator()
            
            var blackboxModules: OrderedDictionary<String, Module> = [:]
            
            if blackboxModels.count != 0 {
                blackboxModules = try Module.getModules(in: blackboxModels, filter: Set(blackbox))
            }
            
            var sclConfig = SCLConfiguration(dffMatches: [DFFMatch(name: "DFFSR,DFFNEGX1,DFFPOSX1", clk: "CLK", d: "D", q: "Q")])
            
            if let sclConfigPath = self.sclConfig {
                guard let sclConfigYML = try? String(contentsOfFile: sclConfigPath) else {
                    throw ValidationError("File not found: \(sclConfigPath)")
                }
                let decoder = YAMLDecoder()
                sclConfig = try decoder.decode(SCLConfiguration.self, from: sclConfigYML)
            }
            
            if let dffOverride = dff {
                sclConfig.dffMatches.last!.name = dffOverride
            }
            
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
                throw ValidationError("No module found.")
            }
            
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
                        
                        let outputName = "\\" + instanceName + ".q"
                        let inputIdentifier = Node.Identifier(instanceName)
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
                            throw ValidationError("Cell \(instanceName) missing either a 'D' or 'Q' port.")
                        }
                        
                        ports.append(Node.Port(instanceName, Python.None, Python.None, Python.None))
                        ports.append(Node.Port(outputName, Python.None, Python.None, Python.None))
                        
                        declarations.append(Node.Input(instanceName))
                        declarations.append(Node.Output(outputName))
                        
                        let inputAssignment = Node.Assign(Node.Lvalue(q), Node.Rvalue(inputIdentifier))
                        let outputAssignment = Node.Assign(Node.Lvalue(outputIdentifier), Node.Rvalue(d))
                        
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
                            let ioName = "\\\(instanceName).\(portName)" + (portInfo.polarity == .input ? ".q" : "")
                            let width = Node.Width(Node.IntConst(portInfo.from), Node.IntConst(portInfo.to))
                            let ioDeclaration = portInfo.polarity == .input ?
                                Node.Output(ioName, width) :
                                Node.Input(ioName, width)
                            let assignStatement = portInfo.polarity == .input ?
                                Node.Assign(Node.Lvalue(Node.Identifier(ioName)), Node.Rvalue(hook.argname)) :
                                Node.Assign(Node.Rvalue(hook.argname), Node.Lvalue(Node.Identifier(ioName)))
                            
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
            
            if declarations.isEmpty {
                print("[Warning]: Failed to detect any flip-flop cells.")
            }
            
            definition.portlist.ports = ports
            definition.items = Python.tuple(declarations + items)
            
            try File.open(output, mode: .write) {
                try $0.print(String.boilerplate)
                try $0.print(Generator.visit(definition))
            }
        }
    }
}
