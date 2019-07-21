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
    var rstBar: String
    var clockBR: String
    var updateBR: String
    var modeControl: String

    init(
        dffCount: Int,
        order: [ChainRegister],
        shift: String,
        sin: String,
        sout: String,
        rstBar: String,
        clockBR: String,
        updateBR: String,
        modeControl: String
    ) {
        self.dffCount = dffCount
        self.order = order
        self.shift = shift
        self.sin = sin
        self.sout = sout
        self.rstBar = rstBar
        self.clockBR = clockBR
        self.updateBR = updateBR
        self.modeControl = modeControl
    }
}