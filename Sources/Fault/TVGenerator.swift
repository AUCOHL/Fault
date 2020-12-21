import Foundation 
import BigInt

protocol ExternalTestVectorGenerator {
    init()
    func generate(file: String, module: String) -> ([TestVector], [Port])
}

class ETVGFactory {
    private static var registry: [String: ExternalTestVectorGenerator.Type] = [:]

    static func register<T: ExternalTestVectorGenerator>(name: String, type: T.Type) -> Bool {
        registry[name] = type
        return true
    }

    static func get(name: String) -> ExternalTestVectorGenerator? {
        guard let metaType = registry[name] else {
            return nil
        }
        return metaType.init()
    }

    static var validNames: [String] {
        return [String](registry.keys)
    }
}

class Atalanta: ExternalTestVectorGenerator {
    required init() {}

    func generate(file: String, module: String) -> ([TestVector], [Port]) {
        
        let tempDir = "\(NSTemporaryDirectory())"

        let folderName = "\(tempDir)thr\(Unmanaged.passUnretained(Thread.current).toOpaque())"
        let _ = "mkdir -p '\(folderName)'".sh()
        defer {
           let _ = "rm -rf '\(folderName)'".sh()
        }

        let output = "\(folderName)/\(module).test"
        let atalanta = "atalanta -t \(output) \(file) > /dev/null 2>&1".sh()

        if atalanta != EX_OK {
            exit(atalanta)
        }
        
        do {
            let (testvectors, inputs) = try TVSet.readFromTest(file: output)
            return (vectors: testvectors, inputs: inputs)
        } catch {
            Stderr.print("Internal software error: \(error)")
            exit(EX_SOFTWARE)
        }
    }

    static let registered = ETVGFactory.register(name: "Atalanta", type: Atalanta.self)
}

class PODEM: ExternalTestVectorGenerator {
    required init() {}

    func generate(file: String, module: String) -> ([TestVector], [Port]) {
        let tempDir = "\(NSTemporaryDirectory())"

        let folderName = "\(tempDir)thr\(Unmanaged.passUnretained(Thread.current).toOpaque())"
        let _ = "mkdir -p '\(folderName)'".sh()
        defer {
           let _ = "rm -rf '\(folderName)'".sh()
        }

        let output = "\(folderName)/\(module).out"
        let podem = "atpg -output \(output) \(file) > /dev/null 2>&1".sh()

        if podem != EX_OK {
            exit(podem)
        }
         do {
            let (testvectors, inputs) = try TVSet.readFromText(file: output)
            return (vectors: testvectors, inputs: inputs)
        } catch {
            Stderr.print("Internal software error: \(error)")
            exit(EX_SOFTWARE)
        }
    }

    static let registered = ETVGFactory.register(name: "PODEM", type: PODEM.self)
}

// MARK: Random Generators
class SwiftRNG: URNG {
    required init() {}

    func generate(bits: Int) -> BigUInt {
        return BigUInt.randomInteger(withMaximumWidth: bits)
    }

    static let registered = URNGFactory.register(name: "swift", type: SwiftRNG.self)
}


class LFSR: URNG {
    static let taps: [UInt: Array<UInt>] = [
        // nbits : Feedback Polynomial
        2: [2, 1],
        3: [3, 2],
        4: [4, 3],
        5: [5, 3],
        6: [6, 5],
        7: [7, 6],
        8: [8, 6, 5, 4],
        9: [9, 5],
        10: [10, 7],
        11: [11, 9],
        12: [12, 11, 10, 4],
        13: [13, 12, 11, 8],
        14: [14, 13, 12, 2],
        15: [15, 14],
        16: [16, 15, 13, 4],
        17: [17, 14],
        18: [18, 11],
        19: [19, 18, 17, 14],
        20: [20, 17],
        21: [21, 19],
        22: [22, 21],
        23: [23, 18],
        24: [24, 23, 22, 17],
        25: [25, 22],
        26: [26, 6, 2, 1],
        27: [27, 5, 2, 1],
        28: [28, 25],
        29: [29, 27],
        30: [30, 6, 4, 1],
        31: [31, 28],
        32: [32, 30, 26, 25],
        64: [64, 63, 61, 60]  
    ];

    var seed: UInt
    var polynomialHex: UInt
    let nbits: UInt 
    
    required init(nbits: UInt = 64) {     
        let max: UInt = (nbits == 64) ? UInt(pow(Double(2),Double(63))-1) : (1 << nbits) - 1  
        let polynomial =  LFSR.taps[nbits]!

        self.seed = UInt.random(in: 1...max)
        self.nbits = nbits
        self.polynomialHex = 0

        for tap in polynomial {
             self.polynomialHex = self.polynomialHex | (1 << (nbits-tap));
        }
    }

    required convenience init() {
        self.init(nbits: 64)
    }

    static func parity(number: UInt) -> UInt {
        var parityVal: UInt = 0
        var numberTemp = number
        while numberTemp != 0 {
            parityVal ^= 1 
            numberTemp = numberTemp & (numberTemp - 1)
        }
        return parityVal
    }

    func rand() -> UInt {
        let feedbackBit: UInt = LFSR.parity(number: self.seed & self.polynomialHex)
        self.seed = (self.seed >> 1) | (feedbackBit << (self.nbits - 1))
        return self.seed
    }

    func generate(bits: Int) -> BigUInt {
        var returnValue: BigUInt = 0
        var generations = bits / Int(nbits)
        let leftover = bits % Int(nbits)
        while generations > 0 {
            returnValue <<= BigUInt(nbits)
            returnValue |= BigUInt(rand())
            generations -= 1
        }
        if leftover > 0 {
            returnValue <<= BigUInt(leftover)
            returnValue |= BigUInt(rand() % ((1 << leftover) - 1))
        }
        return returnValue
    }

    static let registered = URNGFactory.register(name: "LFSR", type: LFSR.self)
}