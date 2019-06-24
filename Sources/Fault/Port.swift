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
}

extension Port: CustomStringConvertible {
    var description: String {
        return "Port(\(name): \(polarity ?? .unknown)[\(from)..\(to)])"
    }
}