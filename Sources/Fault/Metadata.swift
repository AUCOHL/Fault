import Foundation
import Defile

struct ChainRegister: Codable {
    enum Kind: String, Codable {
        case input
        case output
        case dff
        case bypassInput  // bypass when loading the TV (loaded with zeros)
        case bypassOutput // bypass when shifting out the response ()
    }
    var name: String
    var kind: Kind
    var width: Int
    var ordinal: Int
    init(name: String, kind: Kind, ordinal: Int = 0, width: Int = 1) {
        self.name = name
        self.kind = kind
        self.ordinal = ordinal
        self.width = width
    }
}

struct ChainMetadata: Codable {
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
    
    static func extract(file: String) -> ([ChainRegister], Int, Int) {
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
            order: metadata.order,
            boundaryCount: metadata.boundaryCount,
            internalCount: metadata.internalCount
        )
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