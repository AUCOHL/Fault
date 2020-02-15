import Foundation
import BigInt

typealias TestVector = [BigUInt]

struct Coverage: Codable {
    var sa0: [String]
    var sa1: [String]
    init(sa0: [String], sa1: [String]) {
        self.sa0 = sa0
        self.sa1 = sa1
    }
}

struct TVCPair: Codable {
    var vector: TestVector
    var coverage: Coverage

    init(vector: TestVector, coverage: Coverage) {
        self.vector = vector
        self.coverage = coverage
    }
}

struct TVInfo: Codable {
    var inputs: [Port]
    var coverageList: [TVCPair]

    init(
        inputs: [Port],
        coverageList: [TVCPair]
    ) {
        self.inputs = inputs
        self.coverageList = coverageList
    }
}