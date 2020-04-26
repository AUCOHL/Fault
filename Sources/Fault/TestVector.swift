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
    var goldenOutput: String
    init(vector: TestVector, coverage: Coverage, goldenOutput: String) {
        self.vector = vector
        self.coverage = coverage
        self.goldenOutput = goldenOutput
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

struct TVSet: Codable {
    var inputs: [Port]
    var vectors: [TestVector]
    init(
        inputs: [Port],
        vectors: [TestVector]
    ) {
        self.inputs = inputs
        self.vectors = vectors
    }
    static func readFromJson(file: String) throws -> ([TestVector], [Port]) {

        let data = try Data(contentsOf: URL(fileURLWithPath: file), options: .mappedIfSafe)
        guard let tvSet = try? JSONDecoder().decode(TVSet.self, from: data) else {
            fputs("File '\(file)' is invalid.\n", stderr)
            exit(EX_DATAERR)
        }

        return (vectors: tvSet.vectors , inputs: tvSet.inputs)
    }
    static func readFromText(file: String) throws -> ([TestVector], [Port]){
        var inputs: [Port] = []
        var vectors: [TestVector] = []

        guard let reader = LineReader(path: file) else {
            fputs("Test vector set input file '\(file)' not found.\n", stderr)
            exit(EX_DATAERR)
        }

        let ports = reader.nextLine!.components(separatedBy: " ")
        for (index, port) in ports.enumerated(){
            if port != "PI"{
                inputs.append(Port(name: port, at: index))
            }
        }
        inputs = inputs.dropLast(1)

        var readPorts = true
        for line in reader {

            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if (trimmedLine[trimmedLine.startIndex].isNumber){
                let testvector = Array(trimmedLine).map {BigUInt(String($0), radix: 2)!}
                vectors.append(testvector)
                readPorts = false
            } else if readPorts {
                let ports = trimmedLine.components(separatedBy: " ")
                for (index, port) in ports.enumerated(){
                    if port != "PI"{
                        inputs.append(Port(name: port, at: index))
                    }
                }
                inputs = inputs.dropLast(1)
            } else {
                fputs("Warning: Dropped invalid testvector line \(line)", stderr)
            }
        }
        return (vectors: vectors, inputs: inputs)
    }
    static func readFromTest(file: String) throws -> ([TestVector], [Port]) {
        var vectors: [TestVector] = []
        var inputs: [Port] = []
        do {

            let string = try String(contentsOf: URL(fileURLWithPath: file), encoding: .utf8)

            let inputPattern = "(?s)(?<=\\* Primary inputs :).*?(?=\\* Primary outputs:)"
            let tvPattern = "(?s)(?<=: ).*?(?= [0-1]*)"
            var inputResult = ""
            var tvResult = ""
            
            if let range = string.range(of: inputPattern, options: .regularExpression) {
                inputResult = String(string[range])
                inputResult = inputResult.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let ports = inputResult.components(separatedBy: " ")
            
            let regex = try NSRegularExpression(pattern: tvPattern)
            let range = NSRange(string.startIndex..., in: string)
            let results = regex.matches(in: string, range: range)   
            let matches = results.map { String(string[Range($0.range, in: string)!])}     

            for match in matches {
                let testvector = Array(match).map {BigUInt(String($0), radix: 2)!}
                if testvector.count != 0 {
                    vectors.append(testvector)    
                }
            }            
            for (index, port) in ports.enumerated(){  
                if !port.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty{
                    inputs.append(Port(name: port, at: index))
                }
            }
        } catch {
            exit(EX_DATAERR)
        }

        return (vectos: vectors, inputs: inputs)
    }
} 