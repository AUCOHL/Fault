import Foundation

struct Test: Encodable {
    var value: UInt
    var bits: Int
    init(value: UInt, bits: Int) {
        self.value = value
        self.bits = bits
    }
}

typealias TestVector = [Test]

struct Coverage: Encodable {
    var sa0: [String]
    var sa1: [String]
    init(sa0: [String], sa1: [String]) {
        self.sa0 = sa0
        self.sa1 = sa1
    }
}

struct TVCPair: Encodable {
    var vector: TestVector
    var coverage: Coverage

    init(vector: TestVector, coverage: Coverage) {
        self.vector = vector
        self.coverage = coverage
    }
}