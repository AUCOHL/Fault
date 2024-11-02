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
import BigInt
import CoreFoundation
import Defile
import Foundation
import PythonKit

extension Fault {
    struct Assemble: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "asm",
            abstract: "Assemble test vectors and golden outputs from JSON and Verilog files."
        )

        @Option(name: [.customShort("o"), .long], help: "Path to the output vector file.")
        var output: String?

        @Option(name: [.customShort("O"), .long], help: "Path to the golden output file.")
        var goldenOutput: String?

        @Argument(help: "JSON file (.json).")
        var json: String

        @Argument(help: "Verilog file (.v)")
        var verilog: String

        mutating func run() throws {
            // Validate input files
            guard FileManager.default.fileExists(atPath: verilog) else {
                throw ValidationError("Verilog file '\(verilog)' not found.")
            }
            guard FileManager.default.fileExists(atPath: json) else {
                throw ValidationError("JSON file '\(json)' not found.")
            }

            let vectorOutput = output ?? json.replacingExtension(".json", with: ".bin")
            let goldenOutput = goldenOutput ?? json.replacingExtension(".tv.json", with: ".au.bin")

            print("Loading JSON data…")
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: json)) else {
                throw ValidationError("Failed to open test vector JSON file.")
            }

            let decoder = JSONDecoder()
            guard let tvinfo = try? decoder.decode(TVInfo.self, from: data) else {
                throw ValidationError("Test vector JSON file is invalid.")
            }

            // Extract chain metadata
            let (chain, _, _) = ChainMetadata.extract(file: verilog)

            let order = chain.filter { $0.kind != .output }.sorted { $0.ordinal < $1.ordinal }
            let outputOrder = chain.filter { $0.kind != .input }.sorted { $0.ordinal < $1.ordinal }

            let jsInputOrder = tvinfo.inputs
            let jsOutputOrder = tvinfo.outputs

            var inputMap: [String: Int] = [:]
            var outputMap: [String: Int] = [:]

            // Check input order
            let chainOrder = order.filter { $0.kind != .bypassInput }
            guard chainOrder.count == jsInputOrder.count else {
                throw ValidationError(
                    "Number of inputs in the test-vector JSON file (\(jsInputOrder.count)) does not match scan-chain registers (\(chainOrder.count)): Found \(Set(chainOrder.map(\.name)).symmetricDifference(jsInputOrder.map(\.name)))."
                )
            }

            for (i, input) in jsInputOrder.enumerated() {
                let name = input.name.hasPrefix("\\") ? String(input.name.dropFirst()) : input.name
                inputMap[name] = i
                guard chainOrder[i].name == name else {
                    throw ValidationError(
                        "Ordinal mismatch between TV input \(name) and scan-chain register \(chainOrder[i].name)."
                    )
                }
            }

            for (i, output) in jsOutputOrder.enumerated() {
                var name = output.name.hasPrefix("\\") ? String(output.name.dropFirst()) : output.name
                name = name.hasSuffix(".d") ? String(name.dropLast(2)) : name
                outputMap[name] = i
            }

            var outputDecimal: [[BigUInt]] = []
            for tvcPair in tvinfo.coverageList {
                guard let hex = BigUInt(tvcPair.goldenOutput, radix: 16) else {
                    throw ValidationError("Invalid JSON. Golden output must be in hex format.")
                }
                var pointer = 0
                var list: [BigUInt] = []
                let binFromHex = String(hex, radix: 2)
                let padLength = jsOutputOrder.reduce(0) { $0 + $1.width } - binFromHex.count
                let outputBinary = (String(repeating: "0", count: padLength) + binFromHex).reversed()
                for output in jsOutputOrder {
                    let start = outputBinary.index(outputBinary.startIndex, offsetBy: pointer)
                    let end = outputBinary.index(start, offsetBy: output.width)
                    let value = String(outputBinary[start ..< end])
                    list.append(BigUInt(value, radix: 2)!)
                    pointer += output.width
                }
                outputDecimal.append(list)
            }

            var binFileVec = "// test-vector \n"
            var binFileOut = "// fault-free-response \n"
            for (i, tvcPair) in tvinfo.coverageList.enumerated() {
                var binaryString = ""
                for element in order {
                    var value: BigUInt = 0
                    if let locus = inputMap[element.name] {
                        value = tvcPair.vector[locus]
                    } else if element.kind == .bypassInput {
                        value = 0
                    } else {
                        throw ValidationError("Chain register \(element.name) not found in the TVs.")
                    }
                    binaryString += value.pad(digits: element.width, radix: 2).reversed()
                }
                var outputBinary = ""
                for element in outputOrder {
                    var value: BigUInt = 0
                    if let locus = outputMap[element.name] {
                        value = outputDecimal[i][locus]
                        outputBinary += value.pad(digits: element.width, radix: 2)
                    } else if element.kind == .bypassOutput {
                        outputBinary += String(repeating: "x", count: element.width)
                    } else {
                        throw ValidationError(
                            "Mismatch between output port \(element.name) and chained netlist.")
                    }
                }
                binFileVec += binaryString + "\n"
                binFileOut += outputBinary + " \n"
            }

            let vectorCount = tvinfo.coverageList.count
            let vectorLength = order.reduce(0) { $0 + $1.width }

            let vecMetadata = binMetadata(count: vectorCount, length: vectorLength)
            let outMetadata = binMetadata(
                count: vectorCount, length: outputOrder.reduce(0) { $0 + $1.width }
            )

            guard let vecMetadataString = vecMetadata.toJSON() else {
                throw ValidationError("Could not generate metadata string.")
            }
            guard let outMetadataString = outMetadata.toJSON() else {
                throw ValidationError("Could not generate metadata string.")
            }

            try File.open(vectorOutput, mode: .write) {
                try $0.print(String.boilerplate)
                try $0.print("/* FAULT METADATA: '\(vecMetadataString)' END FAULT METADATA */")
                try $0.print(binFileVec, terminator: "")
            }
            try File.open(goldenOutput, mode: .write) {
                try $0.print(String.boilerplate)
                try $0.print("/* FAULT METADATA: '\(outMetadataString)' END FAULT METADATA */")
                try $0.print(binFileOut, terminator: "")
            }

            print("Test vectors and golden outputs assembled successfully.")
        }
    }
}
