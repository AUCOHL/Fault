import Foundation

struct ChainRegister: Codable {
    enum Kind: String, Codable {
        case input
        case output
        case dff
    }
    var name: String
    var kind: Kind
    var width: Int

    init(name: String, kind: Kind, width: Int = 1) {
        self.name = name
        self.kind = kind
        self.width = width
    }
}

struct Metadata: Codable {
    var dffCount: Int
    var order: [ChainRegister]
    var shift: String
    var sin: String
    var sout: String

    init(
        dffCount: Int,
        order: [ChainRegister],
        shift: String,
        sin: String,
        sout: String
    ) {
        self.dffCount = dffCount
        self.order = order
        self.shift = shift
        self.sin = sin
        self.sout = sout
    }
}