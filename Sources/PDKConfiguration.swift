
class DFFMatch: Codable, CustomStringConvertible {
    var name: String
    var clk: String
    var d: String
    var q: String
    
    init(name: String, clk: String, d: String, q: String) {
        self.name = name
        self.clk = clk
        self.d = d
        self.q = q
    }
    
    var description: String {
        return "<DFFMatch \(name): @\(self.clk) \(self.d) -> \(self.q)>"
    } 
}

class MuxInfo: Codable {
    var name: String
    var a: String
    var b: String
    var y: String
    var s: String
    
    init(name: String, a: String, b: String, y: String, s: String) {
        self.name = name
        self.a = a
        self.b = b
        self.y = y
        self.s = s
    }
}

class PDKConfiguration: Codable {
    var dffMatches: [DFFMatch]
    var muxInfo: MuxInfo?
    
    init(dffMatches: [DFFMatch], muxInfo: MuxInfo? = nil) {
        self.dffMatches = dffMatches
        self.muxInfo = muxInfo
    } 
}
