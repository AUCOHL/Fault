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

import Defile
import Foundation
import PythonKit
import ArgumentParser
import Foundation

extension Fault {
    struct Compact: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Compact test vectors and optionally verify using given cell models and netlists."
        )

        @Option(name: [.short, .long], help: "Path to the output file. (Default: input + .compacted.json)")
        var output: String?

        @Option(name: [.short, .long, .customLong("cellModel")], help: "Verify compaction using given cell model.")
        var cellModel: String?

        @Option(name: [.short, .long], help: "Verify compaction for the given netlist.")
        var netlist: String?

        @Argument(help: "The file to process.")
        var file: String

        func run() throws {
            let fileManager = FileManager()
            // Validate input file existence
            guard fileManager.fileExists(atPath: file) else {
                throw ValidationError("File '\(file)' not found.")
            }

            // Validate cell model and netlist options
            if let cellModel = cellModel {
                guard fileManager.fileExists(atPath: cellModel) else {
                    throw ValidationError("Cell model file '\(cellModel)' not found.")
                }
                if !(cellModel.hasSuffix(".v") || cellModel.hasSuffix(".sv")) {
                    print("Warning: Cell model file provided does not end with .v or .sv.")
                }
                guard let _ = netlist else {
                    throw ValidationError("Error: The netlist must be provided to verify compaction.")
                }
            }

            if let netlist = netlist {
                guard fileManager.fileExists(atPath: netlist) else {
                    throw ValidationError("Netlist file '\(netlist)' not found.")
                }
                guard let _ = cellModel else {
                    throw ValidationError("Error: The cell model must be provided to verify compaction.")
                }
            }

            let output = self.output ?? "\(file).compacted.json"

            // Parse JSON File
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            let tvInfo = try JSONDecoder().decode(TVInfo.self, from: data)

            let compactedTV = Compactor.compact(coverageList: tvInfo.coverageList)

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            let jsonData = try encoder.encode(
                TVInfo(
                    inputs: tvInfo.inputs,
                    outputs: tvInfo.outputs,
                    coverageList: compactedTV
                )
            )

            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            try File.open(output, mode: .write) {
                try $0.print(jsonString)
            }

        //     // Verify compaction if cellModel is provided
        //     if let cellModel = cellModel {
        //         print("Running simulations using the compacted set…")
        //         let verifiedOutput = "\(output).verified.json"
        //         let mainArguments = [
        //             CommandLine.arguments[0],
        //             "-c", cellModel,
        //             "-r", "10",
        //             "-v", "10",
        //             "-m", "100",
        //             "--tvSet", output,
        //             "-o", verifiedOutput,
        //             netlist
        //         ]
        //     }
        }
    }
}
