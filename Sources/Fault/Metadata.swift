import Foundation
import Defile

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

struct Chain: Codable {
    var sin: String
    var sout: String
    var shift: String
    var length: Int
    var kind: ScanChain.ChainKind

    init(sin: String, sout: String, shift: String, length: Int, kind: ScanChain.ChainKind) {
        self.sin = sin
        self.sout = sout
        self.shift = shift
        self.length = length
        self.kind = kind
    }
}
struct ChainMetadata: Codable {

    var type: scanStructure
    var scanChains: [Chain]

    init(
        type: scanStructure,
        scanChains: [Chain]
    ) {
        self.type = type
        self.scanChains = scanChains
    }
    
    static func extract(file: String) -> (scanStructure, [Chain]) {

        guard let string = File.read(file) else {
            fputs("Could not read file '\(file)'\n", stderr)
            exit(EX_NOINPUT)
        }

        let slice = string.components(separatedBy: "/* FAULT METADATA: '")[1]
        if !slice.contains("' END FAULT METADATA */") {
            fputs("Fault metadata not terminated.\n", stderr)
            exit(EX_NOINPUT)
        }
        
        let decoder = JSONDecoder()
        let metadataString = slice.components(separatedBy: "' END FAULT METADATA */")[0]
        guard let metadata = try? decoder.decode(ChainMetadata.self, from: metadataString.data(using: .utf8)!) else {
            fputs("Metadata json is invalid.\n", stderr)
            exit(EX_DATAERR)
        }

        return (
            type: metadata.type,
            scanChains: metadata.scanChains
        )
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
struct binMetadata: Codable {
    var count: Int
    var length: Int
    init (
        count: Int,
        length: Int
    ) {
        self.count = count
        self.length = length
    }
    static func extract(file: String) -> (Int, Int) {

        guard let binString = File.read(file) else {
            fputs("Could not read file '\(file)'\n", stderr)
            exit(EX_NOINPUT)
        }

        let slice = binString.components(separatedBy: "/* FAULT METADATA: '")[1]
        if !slice.contains("' END FAULT METADATA */") {
            fputs("Fault metadata not terminated.\n", stderr)
            exit(EX_NOINPUT)
        }
        
        let decoder = JSONDecoder()
        let metadataString = slice.components(separatedBy: "' END FAULT METADATA */")[0]
        guard let metadata = try? decoder.decode(binMetadata.self, from: metadataString.data(using: .utf8)!) else {
            fputs("Metadata json is invalid.\n", stderr)
            exit(EX_DATAERR)
        }
        return(count: metadata.count, length: metadata.length)
    }
}