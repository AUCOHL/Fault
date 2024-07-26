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
import Defile
import Foundation
import PythonKit

struct Port: Codable {
    enum Polarity: String, Codable {
        case input
        case output
        case unknown
    }

    var name: String
    var polarity: Polarity?
    var from: Int
    var to: Int
    var ordinal: Int

    var width: Int {
        from < to ? to - from + 1 : from - to + 1
    }

    var bits: [Int] {
        from < to ? [Int](from ... to) : [Int](to ... from)
    }

    init(name: String, polarity: Polarity? = nil, from: Int = 0, to: Int = 0, at ordinal: Int) {
        self.name = name
        self.polarity = polarity
        self.from = from
        self.to = to
        self.ordinal = ordinal
    }

    static func extract(from definition: PythonObject) throws -> (ports: [String: Port], inputs: [Port], outputs: [Port]) {
        var ports: [String: Port] = [:]

        var paramaters: [String: Int] = [:]
        for (i, portDeclaration) in definition.portlist.ports.enumerated() {
            var polarity: Polarity? = nil
            var from = 0
            var to = 0
            var name: String!
            if Bool(Python.hasattr(portDeclaration, "first"))! {
                let declaration = portDeclaration[dynamicMember: "first"]
                let type = "\(Python.type(declaration).__name__)"
                if type == "Input" {
                    polarity = .input
                } else {
                    polarity = .output
                }
                if declaration.width != Python.None {
                    let msb = Port.evaluate(expr: declaration.width.msb, params: paramaters)
                    let lsb = Port.evaluate(expr: declaration.width.lsb, params: paramaters)
                    from = msb
                    to = lsb
                }
                let firstChild = portDeclaration[dynamicMember: "first"]
                name = "\(firstChild.name)"
            } else {
                name = "\(portDeclaration.name)"
            }

            let port = Port(name: name, polarity: polarity, from: from, to: to, at: i)
            ports[name] = port
        }

        for itemDeclaration in definition.items {
            let type = Python.type(itemDeclaration).__name__
            // Process port declarations further
            if type == "Decl" {
                let declaration = itemDeclaration.list[0]
                let declType = Python.type(declaration).__name__
                if declType == "Parameter" {
                    paramaters["\(declaration.name)"] =
                        Port.evaluate(expr: declaration.value.var, params: paramaters)
                } else if declType == "Input" || declType == "Output" {
                    guard var port = ports["\(declaration.name)"] else {
                        throw "Unknown port \(declaration.name)"
                    }
                    if declaration.width != Python.None {
                        let msb = Port.evaluate(expr: declaration.width.msb, params: paramaters)
                        let lsb = Port.evaluate(expr: declaration.width.lsb, params: paramaters)
                        port.from = msb
                        port.to = lsb
                    }
                    if declType == "Input" {
                        port.polarity = .input
                    } else {
                        port.polarity = .output
                    }
                    ports["\(declaration.name)"] = port
                }
            }
        }

        let inputs: [Port] = ports.values.filter { $0.polarity == .input }.sorted(by: { $0.ordinal < $1.ordinal })
        let outputs: [Port] = ports.values.filter { $0.polarity == .output }.sorted(by: { $0.ordinal < $1.ordinal })
        if ports.count != inputs.count + outputs.count {
            throw RuntimeError("Some ports in \(definition.name) are not properly declared as an input or output.")
        }

        return (ports: ports, inputs: inputs, outputs: outputs)
    }

    private static func evaluate(expr: PythonObject, params: [String: Int]) -> Int {
        let type = "\((Python.type(expr)).__name__)"
        var value = 0
        switch type {
        case "Minus",
             "Plus",
             "Sll":
            let left = Port.evaluate(expr: expr.left, params: params)
            let right = Port.evaluate(expr: expr.right, params: params)
            value = Port.op[type]!(left, right)
        case "IntConst":
            value = Int("\(expr.value)")!
        case "Identifier":
            value = params["\(expr.name)"]!
        default:
            Stderr.print("Got unknown expression type \(type) while evaluating port expression \(expr)")
            exit(EX_DATAERR)
        }
        return value
    }

    static let op = [
        "Minus": sub,
        "Plus": add,
        "Sll": sll,
    ]
}

extension Port: CustomStringConvertible {
    var description: String {
        "Port@\(ordinal)(\(name): \(polarity ?? .unknown)[\(from)..\(to)])"
    }
}

func add(left: Int, right: Int) -> Int {
    left + right
}

func sub(left: Int, right: Int) -> Int {
    left - right
}

func sll(left: Int, right: Int) -> Int {
    left << right
}

struct Module {
    var name: String
    var inputs: [Port]
    var outputs: [Port]
    var definition: PythonObject
    var ports: [Port]
    var portsByName: [String: Port]

    init(name: String, inputs: [Port], outputs: [Port], definition: PythonObject) {
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.definition = definition
        ports = inputs + outputs
        portsByName = ports.reduce(into: [String: Port]()) { $0[$1.name] = $1 }
    }

    static func getModules(in files: [String], filter filterOpt: Set<String>? = nil) throws -> OrderedDictionary<String, Module> {
        let parse = Python.import("pyverilog.vparser.parser").parse
        var result: OrderedDictionary<String, Module> = [:]

        for file in files {
            print("Processing file \(file)…")
            let parseResult = parse([file])
            let ast = parseResult[0]
            let description = ast[dynamicMember: "description"]
            for definition in description.definitions {
                let type = Python.type(definition).__name__
                if type != "ModuleDef" {
                    continue
                }
                let name = String(describing: definition.name)
                print("Processing module \(name)…")
                if let filter = filterOpt {
                    if !filter.contains(name) {
                        continue
                    }
                }
                let (_, inputs, outputs) = try Port.extract(from: definition)
                result[name] = Module(name: name, inputs: inputs, outputs: outputs, definition: definition)
            }
        }

        return result
    }
}

extension Module: CustomStringConvertible {
    var description: String {
        "<Module " + (["\(name)"] + ports.map(\.description)).joined(separator: "\n\t") + "\n>"
    }
}
