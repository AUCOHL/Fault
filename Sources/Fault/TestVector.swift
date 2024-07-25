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
import Defile
import Foundation
import Collections

typealias TestVector = [BigUInt]

extension BigUInt {
    func pad(digits: Int, radix: Int) -> String {
        var padded = String(self, radix: radix)
        let length = padded.count
        if digits > length {
            for _ in 0 ..< (digits - length) {
                padded = "0" + padded
            }
        }
        return padded
    }
}

struct Coverage: Codable {
    var sa0: [String]
    var sa1: [String]
    init(sa0: [String], sa1: [String]) {
        self.sa0 = sa0
        self.sa1 = sa1
    }
}

struct TVCPair: Codable {
    var vector: TestVector
    var coverage: Coverage
    var goldenOutput: String
    init(vector: TestVector, coverage: Coverage, goldenOutput: String) {
        self.vector = vector
        self.coverage = coverage
        self.goldenOutput = goldenOutput
    }
}

struct TVInfo: Codable {
    var inputs: [Port]
    var outputs: [Port]
    var coverageList: [TVCPair]
    init(
        inputs: [Port],
        outputs: [Port],
        coverageList: [TVCPair]
    ) {
        self.inputs = inputs
        self.outputs = outputs
        self.coverageList = coverageList
    }

    static func fromJSON(file: String) throws -> TVInfo {
        let data = try Data(contentsOf: URL(fileURLWithPath: file), options: .mappedIfSafe)
        return try JSONDecoder().decode(TVInfo.self, from: data)
    }
}

enum TVSet {
    static func readFromJson(file: String) throws -> ([TestVector], [Port]) {
        guard let tvInfo = try? TVInfo.fromJSON(file: file) else {
            Stderr.print("File '\(file)' is invalid.")
            exit(EX_DATAERR)
        }
        let vectors = tvInfo.coverageList.map(\.vector)
        return (vectors: vectors, inputs: tvInfo.inputs)
    }

    static func readFromText(file path: String) throws -> ([TestVector], [Port]) {
        var inputs: [Port] = []
        var vectors: [TestVector] = []

        guard let file = File.open(path) else {
            Stderr.print("Test vector set input file '\(path)' not found.")
            exit(EX_DATAERR)
        }

        let lines = file.lines!

        let ports = lines[0].components(separatedBy: " ")
        for (index, port) in ports.enumerated() {
            if port != "PI" {
                inputs.append(Port(name: port, at: index))
            }
        }
        inputs = inputs.dropLast(1)

        var readPorts = true
        for line in lines[1...] {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine[trimmedLine.startIndex].isNumber {
                let testvector = Array(trimmedLine).map { BigUInt(String($0), radix: 2)! }
                vectors.append(testvector)
                readPorts = false
            } else if readPorts {
                let ports = trimmedLine.components(separatedBy: " ")
                for (index, port) in ports.enumerated() {
                    if port != "PI" {
                        inputs.append(Port(name: port, at: index))
                    }
                }
                inputs = inputs.dropLast(1)
            } else {
                Stderr.print("Warning: Dropped invalid testvector line \(line)")
            }
        }
        return (vectors: vectors, inputs: inputs)
    }

    static func readFromTest(_ file: String, withInputsFrom bench: String) throws -> ([TestVector], [Port]) {
        var inputDict: OrderedDictionary<String, Port> = [:]
        let benchStr = File.read(bench)!
        let inputRx = #/INPUT\(([^\(\)]+?)(\[\d+\])?\)/#
        var ordinal = -1
        for line in benchStr.components(separatedBy: "\n") {
            if let match = try? inputRx.firstMatch(in: line) {
                let name = String(match.1)
                inputDict[name] = inputDict[name] ?? Port(name: name, polarity: .input, from: 0, to: -1, at: { ordinal += 1; return ordinal }())
                inputDict[name]!.to += 1
            }
        }
        
        let inputs: [Port] = inputDict.values.sorted { $0.ordinal < $1.ordinal }
        var vectors: [TestVector] = []
        let testStr = File.read(file)!
        let tvRx = #/(\d+):\s*([01]+)/#
        for line in testStr.components(separatedBy: "\n") {
            if let match = try? tvRx.firstMatch(in: line) {
                let vectorStr = match.2
                guard var vectorCat = BigUInt(String(vectorStr.reversed()), radix: 2) else {
                    Stderr.print("Failed to parse test vector in .test file: \(vectorStr)")
                    exit(EX_DATAERR)
                }
                let tv: TestVector = inputs.map {
                    input in
                    let value = vectorCat & ((1 << input.width) - 1)
                    vectorCat >>= input.width
                    return value
                }
                vectors.append(tv)
            }
        }

        return (vectors: vectors, inputs: inputs)
    }
}
