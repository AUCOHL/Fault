// Copyright (C) 2019 The American University in Cairo
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import BigInt
import Defile
import Foundation


protocol TVGenerator {
    var current: BigUInt { get set }
    
    init(allBits: Int, seed: UInt)
    
    func generate(count: Int)
}

extension TVGenerator {
    mutating func get(bits: Int) -> BigUInt {
        let mask = (BigUInt(1) << bits) - 1
        let result = current & mask
        current >>= bits
        return result
    }
}

enum TVGeneratorFactory {
    private static var registry: [String: TVGenerator.Type] = [:]

    static func register<T: TVGenerator>(name: String, type: T.Type) -> Bool {
        registry[name] = type
        return true
    }

    static func get(name: String) -> TVGenerator.Type? {
        guard let metaType = registry[name] else {
            return nil
        }
        return metaType
    }

    static var validNames: [String] {
        [String](registry.keys)
    }
}

class SwiftRNG: TVGenerator {
    var current: BigUInt
    var bits: Int
    var rng: ARC4RandomNumberGenerator
    
    required init(allBits bits: Int, seed: UInt) {
        self.current = 0
        self.bits = bits
        self.rng = ARC4RandomNumberGenerator(seed: seed) 
    }

    func generate(count: Int) {
        self.current = BigUInt.randomInteger(withMaximumWidth: bits, using: &self.rng)
    }

    static let registered = TVGeneratorFactory.register(name: "swift", type: SwiftRNG.self)
}

class LFSR: TVGenerator {
    var current: BigUInt
    var bits: Int
    
    static let taps: [UInt: [UInt]] = [
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
        64: [64, 63, 61, 60],
    ]

    var seed: UInt
    var polynomialHex: UInt
    let nbits: UInt

    required init(allBits bits: Int, nbits: UInt, seed: UInt) {
        self.seed = seed
        self.nbits = nbits
        self.bits = bits
        self.current = 0
        
        let polynomial = LFSR.taps[nbits]!

        polynomialHex = 0

        for tap in polynomial {
            polynomialHex = polynomialHex | (1 << (nbits - tap))
        }
    }

    required convenience init(allBits: Int, seed: UInt) {
        self.init(allBits: allBits, nbits: 64, seed: seed)
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
        let feedbackBit: UInt = LFSR.parity(number: seed & polynomialHex)
        seed = (seed >> 1) | (feedbackBit << (nbits - 1))
        return seed
    }

    func generate(count: Int) {
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
        current = returnValue
    }

    static let registered = TVGeneratorFactory.register(name: "LFSR", type: LFSR.self)
}

class PatternGenerator: TVGenerator {
    var current: BigUInt = 0
    var bits: Int = 0
    
    required init(allBits bits: Int, seed _: UInt) {
        self.bits = bits
        self.current = 0
    }

    func generate(count: Int) {
        let selector = count / 2
        let complement = (count % 2) == 1
        self.current = 0
        if selector == 0 {
            // Nothing, it's already all zeroes
        } else if selector == 1 {
            // Half-and-half
            let halfBits = bits / 2
            current = (BigUInt(1) << halfBits) - 1
        } else if selector == 2 {
            // Alternating 0s and 1s
            for _ in 0 ..< bits {
                current = (current << 1) | ((current & 1) ^ 1)
            }
        } else {
            // Moving (min 32, total / 4)-bit window
            let windowShift = (selector - 3)
            let windowSize = max(1, min(32, bits / 4))
            let window = (BigUInt(1) << windowSize) - 1
            current |= (window << windowShift)
        }
        
        let mask = (BigUInt(1) << bits) - 1
        current &= mask
        
        if (complement) {
            current ^= mask
        }
    }
    
    static let registered = TVGeneratorFactory.register(name: "pattern", type: PatternGenerator.self)
}



// TODO: Unify external and internal TV generators
protocol ExternalTestVectorGenerator {
    init()
    func generate(file: String, module: String) -> ([TestVector], [Port])
}

enum ETVGFactory {
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
        [String](registry.keys)
    }
}

class Atalanta: ExternalTestVectorGenerator {
    required init() {}

    func generate(file: String, module: String) -> ([TestVector], [Port]) {
        let output = file.replacingExtension(".bench", with: ".test")
        let atalanta = "atalanta -t \(output) \(file)".sh()

        if atalanta != EX_OK {
            exit(atalanta)
        }

        do {
            let (testvectors, inputs) = try TVSet.readFromTest(output, withInputsFrom: file)
            return (vectors: testvectors, inputs: inputs)
        } catch {
            Stderr.print("Internal software error: \(error)")
            exit(EX_SOFTWARE)
        }
    }

    static let registered = ETVGFactory.register(name: "Atalanta", type: Atalanta.self)
}

class Quaigh: ExternalTestVectorGenerator {
    required init() {}

    func generate(file: String, module: String) -> ([TestVector], [Port]) {
        let output = file.replacingExtension(".bench", with: ".test")
        let quaigh = "quaigh atpg \(file) -o \(output)".sh()

        if quaigh != EX_OK {
            exit(quaigh)
        }

        do {
            let (testvectors, inputs) = try TVSet.readFromTest(output, withInputsFrom: file)
            return (vectors: testvectors, inputs: inputs)
        } catch {
            Stderr.print("Internal software error: \(error)")
            exit(EX_SOFTWARE)
        }
    }

    static let registered = ETVGFactory.register(name: "Quaigh", type: Quaigh.self)
}

class PODEM: ExternalTestVectorGenerator {
    required init() {}

    func generate(file: String, module: String) -> ([TestVector], [Port]) {
        let tempDir = "\(NSTemporaryDirectory())"

        let folderName = "\(tempDir)thr\(Unmanaged.passUnretained(Thread.current).toOpaque())"
        try? FileManager.default.createDirectory(atPath: folderName, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? FileManager.default.removeItem(atPath: folderName)
        }

        let output = "\(folderName)/\(module).out"
        let podem = "atpg-podem -output \(output) \(file) > /dev/null 2>&1".sh()

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
