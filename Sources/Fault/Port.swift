class Port {
    enum Polarity {
        case input
        case output
        case unknown
    }
    var name: String
    var polarity: Polarity?
    var from: Int
    var to: Int

    var width: Int {
        return from < to ? to - from + 1 : from - to + 1
    }

    init(name: String) {
        self.name = name
        self.from = 0
        self.to = 0
    }
}

extension Port: CustomStringConvertible {
    var description: String {
        return "Port(\(name): \(polarity ?? .unknown)[\(from)..\(to)])"
    }
}