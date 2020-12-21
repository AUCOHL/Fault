import Foundation
import BigInt
import Defile

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
    var outputs: [Port]
    var coverageList: [TVCPair]
    init(
        inputs: [Port],
        outputs: [Port],
        coverageList: [TVCPair]
    ) {
        self.inputs = inputs
        self.outputs = outputs
        self.coverageList = coverageList
    }
}

class TVSet {
    static func readFromJson(file: String) throws -> ([TestVector], [Port]) {
        let data = try Data(contentsOf: URL(fileURLWithPath: file), options: .mappedIfSafe)
        guard let tvInfo = try? JSONDecoder().decode(TVInfo.self, from: data) else {
            Stderr.print("File '\(file)' is invalid.")
            exit(EX_DATAERR)
        }
        let vectors = tvInfo.coverageList.map{ $0.vector }
        return (vectors: vectors , inputs: tvInfo.inputs)
    }

    static func readFromText(file path: String) throws -> ([TestVector], [Port]){
        var inputs: [Port] = []
        var vectors: [TestVector] = []
        
        guard let file = File.open(path) else {
            Stderr.print("Test vector set input file '\(path)' not found.")
            exit(EX_DATAERR)
        }

        let lines = file.lines!

        let ports = lines[0].components(separatedBy: " ")
        for (index, port) in ports.enumerated() {
            if port != "PI"{
                inputs.append(Port(name: port, at: index))
            }
        }
        inputs = inputs.dropLast(1)

        var readPorts = true
        for line in lines[1...] {

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
                Stderr.print("Warning: Dropped invalid testvector line \(line)")
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

            var count = 0;
            for port in ports {  
                if !port.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty{ 
                    if let match = multiBitRegex.firstMatch(in: port, options: [], range: NSRange(location: 0, length: port.utf16.count)) {
                        if let nameRange = Range(match.range(at: 1), in: port) {                            
                            portName = String(port[nameRange])
                            let exists = multiBitPorts[portName] != nil
                            if !exists {
                                multiBitPorts[portName] = Port(name: portName, at: count)
                                multiBitPorts[portName]!.from = 0
                            } 
                        }
                        if let bitRange = Range(match.range(at: 2), in: port) {
                            bitNumber = Int(port[bitRange])!
                            multiBitPorts[portName]!.to = bitNumber
                        }
                    }
                    else {
                        inputs.append(Port(name: port, at: count))
                    } 
                    count += 1                    
                }
            }

            var vectorSlices: [Range<Int>] =  []
            for port in multiBitPorts.values {
                inputs.append(port)
                vectorSlices.append(port.ordinal..<(port.to+port.ordinal)+1)
            }
            vectorSlices.sort { $0.lowerBound < $1.lowerBound }

            let vectorRegex = try NSRegularExpression(pattern: tvPattern)
            let range = NSRange(string.startIndex..., in: string)
            let results = vectorRegex.matches(in: string, range: range)   
            let matches = results.map { String(string[Range($0.range, in: string)!])}     

            inputs.sort {$0.ordinal < $1.ordinal }
        
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