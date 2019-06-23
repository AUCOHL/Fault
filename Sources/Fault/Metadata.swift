import Foundation

struct Metadata: Codable {
    var dffCount: Int
    var testEnableIdentifier: String
    var testInputIdentifier: String
    var testOutputIdentifier: String

    init(dffCount: Int, testEnableIdentifier: String, testInputIdentifier: String, testOutputIdentifier: String) {
        self.dffCount = dffCount
        self.testEnableIdentifier = testEnableIdentifier
        self.testInputIdentifier = testInputIdentifier
        self.testOutputIdentifier = testOutputIdentifier
    }
}