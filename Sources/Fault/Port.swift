import PythonKit

class Port: Codable {
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
        return from < to ? to - from + 1 : from - to + 1
    }

    init(name: String, at ordinal: Int) {
        self.name = name
        self.from = 0
        self.to = 0
        self.ordinal = ordinal
    }

    static func extract(from definition: PythonObject) throws -> (ports: [String: Port], inputs: [Port], outputs: [Port]) {
        var ports: [String: Port] = [:]
        var inputs: [Port] = []
        var outputs: [Port] = []

        for (i, portDeclaration) in definition.portlist.ports.enumerated() {
            let port = Port(name: "\(portDeclaration.name)", at: i)
            ports["\(portDeclaration.name)"] = port
        }

        for itemDeclaration in definition.items {
            let type = Python.type(itemDeclaration).__name__

            // Process port declarations further
            if type == "Decl" {
                let declaration = itemDeclaration.list[0]
                let declType = Python.type(declaration).__name__
                if declType == "Input" || declType == "Output" {
                    guard let port = ports["\(declaration.name)"] else {
                        throw "Unknown port \(declaration.name)"
                    }
                    if declaration.width != Python.None {
                        port.from = Int("\(declaration.width.msb)")!
                        port.to = Int("\(declaration.width.lsb)")!
                    }
                    if declType == "Input" {
                        port.polarity = .input
                        inputs.append(port)
                    } else {
                        port.polarity = .output
                        outputs.append(port)
                    }
                }
            }
        }

        inputs.sort { $0.ordinal < $1.ordinal }
        outputs.sort { $0.ordinal < $1.ordinal }

        return (ports: ports, inputs: inputs, outputs: outputs)
    }
}

extension Port: CustomStringConvertible {
    var description: String {
        return "Port(\(name): \(polarity ?? .unknown)[\(from)..\(to)])"
    }
}