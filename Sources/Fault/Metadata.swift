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
    var boundaryCount: Int
    var internalCount: Int
    var order: [ChainRegister]
    var shift: String
    var sin: String
    var sout: String

    init(
        boundaryCount: Int,
        internalCount: Int,
        order: [ChainRegister],
        shift: String,
        sin: String,
        sout: String
    ) {
        self.boundaryCount = boundaryCount
        self.internalCount = internalCount
        self.order = order
        self.shift = shift
        self.sin = sin
        self.sout = sout
    }
}

struct JTAGMetadata: Codable {
    var IRLength: Int 
    var boundaryCount: Int
    var internalCount: Int
    var tdi: String
    var tms: String
    var tck: String
    var tdo: String
    var trst: String

    init (
        IRLength: Int,
        boundaryCount: Int,
        internalCount: Int,
        tdi: String,
        tms: String, 
        tck: String,
        tdo: String,
        trst: String
    ) {
        self.IRLength = IRLength
        self.boundaryCount = boundaryCount
        self.internalCount = internalCount
        self.tdi = tdi
        self.tms = tms
        self.tck = tck
        self.tdo = tdo
        self.trst = trst
    }
}
