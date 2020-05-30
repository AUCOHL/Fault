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
            let multibitPattern = "(?<name>.*).{1}(?<=\\[)(?<bit>[0-9]+)(?=\\])"

            var inputResult = ""            
            if let range = string.range(of: inputPattern, options: .regularExpression) {
                inputResult = String(string[range])
                inputResult = inputResult.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let ports = inputResult.components(separatedBy: " ")
            let multiBitRegex = try NSRegularExpression(pattern: multibitPattern)

            var multiBitPorts : [String: Port] = [:]
            var portName:String = "", bitNumber:Int = 0
            for (index, port) in ports.enumerated(){  
                if !port.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty{ 
                    if let match = multiBitRegex.firstMatch(in: port, options: [], range: NSRange(location: 0, length: port.utf16.count)) {
                        if let nameRange = Range(match.range(at: 1), in: port) {                            
                            portName = String(port[nameRange])
                            let exists = multiBitPorts[portName] != nil
                            if !exists {
                                multiBitPorts[portName] = Port(name: portName, at: index)
                                multiBitPorts[portName]!.from = 0
                            } 
                        }
                        if let bitRange = Range(match.range(at: 2), in: port) {
                            bitNumber = Int(port[bitRange])!
                            multiBitPorts[portName]!.to = bitNumber
                        }
                    }
                    else {
                        inputs.append(Port(name: port, at: index))
                    }                     
                }
            }

            var vectorSlices: [Range<Int>] =  []
            for port in multiBitPorts.values {
                inputs.append(port)
                vectorSlices.append(port.ordinal..<(port.to+port.ordinal)+1)
            }

              
            let vectorRegex = try NSRegularExpression(pattern: tvPattern)
            let range = NSRange(string.startIndex..., in: string)
            let results = vectorRegex.matches(in: string, range: range)   
            let matches = results.map { String(string[Range($0.range, in: string)!])}     

            for match in matches {
                let vector = Array(match)
                if vector.count != 0 {
                    var testVector: TestVector = []
                    var start = 0
                    for slice in vectorSlices {
                        let lowerVec = vector[start..<slice.lowerBound].map{ BigUInt(String($0), radix: 2)!}
                        if lowerVec.count != 0 {
                            testVector.append(contentsOf: lowerVec)
                        }

                        let middleVec = BigUInt(String(vector[slice]), radix: 2)!
                        testVector.append(middleVec)
        
                        start = slice.upperBound
                    }
                    
                    if start < vector.count {
                        let remVector = vector[start...].map{ BigUInt(String($0), radix: 2)!}
                        testVector.append(contentsOf: remVector)
                    }

                    vectors.append(testVector)  
                }
            }         
        } catch {
            exit(EX_DATAERR)
        }

        return (vectos: vectors, inputs: inputs)
    }
} 