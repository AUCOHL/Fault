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

import ArgumentParser
import CoreFoundation
import Defile
import Foundation
import PythonKit
import BigInt

extension Fault {
    struct Bench: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a benchmark file from Verilog or JSON cell models."
        )
        
        @Option(name: [.short, .long], help: "Path to the output file. (Default: input + .bench)")
        var output: String?
        
        @Option(name: [.short, .long, .customLong("cellModel")], help: "Path to cell models file. (.v) files are converted to (.json). If .json is available, it could be supplied directly.")
        var cellModel: String
        
        @Argument(help: "Verilog or JSON file.")
        var file: String
        
        mutating func run() throws {
            let fileManager = FileManager.default
            
            // Validate input files
            guard fileManager.fileExists(atPath: file) else {
                throw ValidationError("File '\(file)' not found.")
            }
            guard fileManager.fileExists(atPath: cellModel) else {
                throw ValidationError("Cell model file '\(cellModel)' not found.")
            }
            
            let output = self.output ?? "\(file).bench"
            
            var cellModelsFile = cellModel
            
            // Convert .v to .json if needed
            if cellModel.hasSuffix(".v") || cellModel.hasSuffix(".sv") {
                print("Creating JSON for the cell models…")
                cellModelsFile = "\(cellModel).json"
                
                // Extract cell definitions from Verilog
                let cellModels = "grep -E -- \"\\bmodule\\b|\\bendmodule\\b|and|xor|or|not(\\s+|\\()|buf|input.*;|output.*;\" \(cellModel)".shOutput()
                let pattern = "(?s)(?:module).*?(?:endmodule)"
                
                var cellDefinitions = ""
                if let range = cellModels.output.range(of: pattern, options: .regularExpression) {
                    cellDefinitions = String(cellModels.output[range])
                }
                
                do {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let range = NSRange(cellModels.output.startIndex..., in: cellModels.output)
                    let results = regex.matches(in: cellModels.output, range: range)
                    let matches = results.map { String(cellModels.output[Range($0.range, in: cellModels.output)!]) }
                    
                    cellDefinitions = matches.joined(separator: "\n")
                    
                    let folderName = "\(NSTemporaryDirectory())/thr\(Unmanaged.passUnretained(Thread.current).toOpaque())"
                    let _ = "mkdir -p \(folderName)".sh()
                    
                    defer {
                        let _ = "rm -rf \(folderName)".sh()
                    }
                    let cellFile = "\(folderName)/cells.v"
                    
                    try File.open(cellFile, mode: .write) {
                        try $0.print(cellDefinitions)
                    }
                    
                    // Parse using Pyverilog
                    let parse = Python.import("pyverilog.vparser.parser").parse
                    let ast = parse([cellFile])[0]
                    let description = ast[dynamicMember: "description"]
                    
                    let cells = try BenchCircuit.extract(definitions: description.definitions)
                    let circuit = BenchCircuit(cells: cells)
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let data = try encoder.encode(circuit)
                    
                    guard let string = String(data: data, encoding: .utf8) else {
                        throw ValidationError("Could not create UTF-8 string.")
                    }
                    
                    try File.open(cellModelsFile, mode: .write) {
                        try $0.print(string)
                    }
                    
                } catch {
                    throw ValidationError("Internal error: \(error)")
                }
            } else if !cellModel.hasSuffix(".json") {
                print("Warning: Cell model file provided does not end with .v or .sv or .json. It will be treated as a JSON file.")
            }
            
            // Process library cells
            let data = try Data(contentsOf: URL(fileURLWithPath: cellModelsFile), options: .mappedIfSafe)
            guard let benchCells = try? JSONDecoder().decode(BenchCircuit.self, from: data) else {
                throw ValidationError("File '\(cellModel)' is invalid.")
            }
            
            let cellsDict = benchCells.cells.reduce(into: [String: BenchCell]()) { $0[$1.name] = $1 }
            
            // Parse using Pyverilog
            let parse = Python.import("pyverilog.vparser.parser").parse
            let ast = parse([file])[0]
            let description = ast[dynamicMember: "description"]
            var moduleDef: PythonObject?
            
            for definition in description.definitions {
                if Python.type(definition).__name__ == "ModuleDef" {
                    moduleDef = definition
                    break
                }
            }
            
            guard let definition = moduleDef else {
                throw ValidationError("No module found.")
            }
            
            let (_, inputs, outputs) = try Port.extract(from: definition)
            
            var inputNames: [String] = []
            var usedInputs: [String] = []
            var floatingOutputs: [String] = []
            var benchStatements = ""
            
            for input in inputs {
                if input.width > 1 {
                    let range = (input.from > input.to) ? input.to ... input.from : input.from ... input.to
                    for index in range {
                        let name = "\(input.name)[\(index)]"
                        inputNames.append(name)
                        benchStatements += "INPUT(\(name)) \n"
                    }
                } else {
                    let name = input.name
                    inputNames.append(name)
                    benchStatements += "INPUT(\(name)) \n"
                }
            }
            
            for item in definition.items {
                let type = Python.type(item).__name__
                
                if type == "InstanceList" {
                    let instance = item.instances[0]
                    let cellName = String(describing: instance.module)
                    let instanceName = String(describing: instance.name)
                    let cell = cellsDict[cellName]!
                    
                    var inputs: [String: String] = [:]
                    var outputs: [String] = []
                    
                    for hook in instance.portlist {
                        let portname = String(describing: hook.portname)
                        let argname = String(describing: hook.argname)
                        
                        if portname == cell.output {
                            outputs.append(argname)
                        } else {
                            inputs[portname] = argname
                        }
                    }
                    
                    let statements = try cell.extract(name: instanceName, inputs: inputs, output: outputs)
                    benchStatements += "\(statements) \n"
                    
                    usedInputs.append(contentsOf: Array(inputs.values))
                    
                } else if type == "Assign" {
                    let right = Python.type(item.right.var).__name__ == "Pointer" ?
                        "\(item.right.var.var)[\(item.right.var.ptr)]" :
                        "\(item.right.var)"
                    
                    let left = Python.type(item.left.var).__name__ == "Pointer" ?
                        "\(item.left.var.var)[\(item.left.var.ptr)]" :
                        "\(item.left.var)"
                    
                    if right == "1'b0" || right == "1'h0" {
                        print("[Warning]: Constants are not recognized by atalanta. Removing \(left) associated gates and nets..")
                        floatingOutputs.append(left)
                    } else {
                        let statement = "\(left) = BUFF(\(right)) \n"
                        benchStatements += statement
                        
                        usedInputs.append(right)
                    }
                }
            }
            
            let ignoredInputs = inputNames.filter { !usedInputs.contains($0) }
            print("Found \(ignoredInputs.count) floating inputs.")
            
            let filteredOutputs = outputs.filter { !floatingOutputs.contains($0.name) }
            for output in filteredOutputs {
                if output.width > 1 {
                    let range = (output.from > output.to) ? output.to ... output.from : output.from ... output.to
                    for index in range {
                        benchStatements += "OUTPUT(\(output.name)[\(index)]) \n"
                    }
                } else {
                    benchStatements += "OUTPUT(\(output.name)) \n"
                }
            }
            
            var floatingStatements = ""
            for input in ignoredInputs {
                floatingStatements += "OUTPUT(\(input)) \n"
            }
            
            let boilerplate = """
            #    Bench for \(definition.name)
            #    Automatically generated by Fault.
            #    Don't modify. \n
            """
            
            try File.open(output, mode: .write) {
                try $0.print(boilerplate)
                try $0.print(floatingStatements.dropLast())
                try $0.print(benchStatements)
            }
            
            print("Benchmark file generated successfully at \(output).")
        }
    }
}
