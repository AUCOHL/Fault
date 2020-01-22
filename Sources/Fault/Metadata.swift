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
    var boundaryOrder: [ChainRegister]
    var internalOrder: [ChainRegister]
    var shift: String
    var sinBoundary: String
    var sinInternal: String
    var soutBoundary: String
    var soutInternal: String

    init(
        boundaryCount: Int,
        internalCount: Int,
        boundaryOrder: [ChainRegister],
        internalOrder: [ChainRegister],
        shift: String,
        sinBoundary: String,
        sinInternal: String,
        soutBoundary: String,
        soutInternal: String
    ) {
        self.boundaryCount = boundaryCount
        self.internalCount = internalCount
        self.boundaryOrder = boundaryOrder
        self.internalOrder = internalOrder
        self.shift = shift
        self.sinBoundary = sinBoundary
        self.sinInternal = sinInternal
        self.soutBoundary = soutBoundary
        self.soutInternal = soutInternal
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
