import Foundation
import Defile
import PythonKit

class Simulator {
    enum Behavior: Int {
        case holdHigh = 1
        case holdLow = 0
    }

    private static func pseudoRandomVerilogGeneration(
        using testVector: TestVector,
        for faultPoints: Set<String>,
        in file: String,
        module: String,
        with cells: String, 
        ports: [String: Port],
        inputs: [Port],
        ignoring ignoredInputs: Set<String>,
        behavior: [Behavior],
        outputs: [Port],
        stuckAt: Int,
        cleanUp: Bool,
        filePrefix: String = "."
    ) throws -> [String] {
        var portWires = ""
        var portHooks = ""
        var portHooksGM = ""
        for (rawName, port) in ports {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name) ;\n"
            portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name).gm ;\n"
            portHooks += ".\(name) ( \(name) ) , "
            portHooksGM += ".\(name) ( \(name).gm ) , "
        }

        let folderName = "\(filePrefix)/thr\(Unmanaged.passUnretained(Thread.current).toOpaque())"
        let _ = "mkdir -p \(folderName)".sh()

        var inputAssignment = ""
        var fmtString = ""
        var inputList = ""

        for (i, input) in inputs.enumerated() {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"

            inputAssignment += "        \(name) = \(testVector[i]) ;\n"
            inputAssignment += "        \(name).gm = \(name) ;\n"

            fmtString += "%d "
            inputList += "\(name) , "
        }

        for (i, rawName) in ignoredInputs.enumerated() {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"

            inputAssignment += "        \(name) = \(behavior[i].rawValue) ;\n"
            inputAssignment += "        \(name).gm = \(behavior[i].rawValue) ;\n"
        }

        fmtString = String(fmtString.dropLast(1))
        inputList = String(inputList.dropLast(2))

        var outputComparison = ""
        for output in outputs {
            let name = (output.name.hasPrefix("\\")) ? output.name : "\\\(output.name)"
            outputComparison += " ( \(name) != \(name).gm ) || "
        }
        outputComparison = String(outputComparison.dropLast(3))

        var faultForces = ""
        for fault in faultPoints {
            faultForces += "        force uut.\(fault) = \(stuckAt) ; \n"   
            faultForces += "        if (difference) $display(\"\(fault)\") ; \n"
            faultForces += "        #1 ; \n"
            faultForces += "        release uut.\(fault) ;\n"
        }

        let bench = """
        \(String.boilerplate)

        `include "\(cells)"
        `include "\(file)"

        module FaultTestbench;

        \(portWires)

            \(module) uut(
                \(portHooks.dropLast(2))
            );
            \(module) gm(
                \(portHooksGM.dropLast(2))
            );

            wire difference ;
            assign difference = (\(outputComparison));

            integer counter;

            initial begin
        \(inputAssignment)
        \(faultForces)
                $finish;
            end

        endmodule
        """;

        let tbName = "\(folderName)/tb.sv"
        try File.open(tbName, mode: .write) {
            try $0.print(bench)
        }

        let aoutName = "\(folderName)/a.out"

        let iverilogResult =
            "iverilog -Ttyp -o \(aoutName) \(tbName) 2>&1 > /dev/null".sh()
        if iverilogResult != EX_OK {
            exit(Int32(iverilogResult))
        }

        let vvpTask = "vvp \(aoutName)".shOutput()

        if vvpTask.terminationStatus != EX_OK {
            exit(vvpTask.terminationStatus)
        }

        if cleanUp {
            let _ = "rm -rf \(folderName)".sh()
        }

        return vvpTask.output.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    static func simulate(
        for faultPoints: Set<String>,
        in file: String,
        module: String,
        with cells: String,
        ports: [String: Port],
        inputs: [Port],
        ignoring ignoredInputs: Set<String> = [],
        behavior: [Behavior] = [],
        outputs: [Port],
        initialVectorCount: Int,
        incrementingBy increment: Int,
        minimumCoverage: Float,
        ceiling: Int,
        sampleRun: Bool
    ) throws -> (coverageList: [TVCPair], coverage: Float) {
        
        var testVectorHash: Set<TestVector> = []

        var coverageList: [TVCPair] = []
        var coverage: Float = 0.0

        var sa0Covered: Set<String> = []
        sa0Covered.reserveCapacity(faultPoints.count)
        var sa1Covered: Set<String> = []
        sa1Covered.reserveCapacity(faultPoints.count)

        var totalTVAttempts = 0
        var tvAttempts = initialVectorCount

        while coverage < minimumCoverage && totalTVAttempts < ceiling {
            if totalTVAttempts > 0 {
                print("Minimum coverage not met (\(coverage * 100)%/\(minimumCoverage * 100)%,) incrementing to \(totalTVAttempts + tvAttempts)…")
            }

            var futureList: [Future<Coverage>] = []
            var testVectors: [TestVector] = []
            var randomGenerator: [LFSR] = []

            let nbits: UInt = 32;
            for _ in inputs {
                randomGenerator.append(
                    LFSR(nbits: nbits)
                )
            }

            for _ in 0..<tvAttempts {
                var testVector: TestVector = []
                // for input in inputs {
                //     let max: UInt = (1 << UInt(input.width)) - 1
                //     testVector.append(
                //         UInt.random(in: 0...max)
                //     )
                // }
                for i in 0..<inputs.count {
                    testVector.append(   
                      randomGenerator[i].next(outputBits: UInt(inputs[i].width))
                    )
                }
                if testVectorHash.contains(testVector) {
                    continue
                }
                testVectorHash.insert(testVector)
                testVectors.append(testVector)
            }

            if testVectors.count < tvAttempts {
                print("Skipped \(tvAttempts - testVectors.count) duplicate generated test vectors.")
            }
            let tempDir = "\(NSTemporaryDirectory())"

            for vector in testVectors {
                let future = Future<Coverage> {
                    do {
                        let sa0 =
                            try Simulator.pseudoRandomVerilogGeneration(
                                using: vector,
                                for: faultPoints,
                                in: file,
                                module: module,
                                with: cells,
                                ports: ports,
                                inputs: inputs,
                                ignoring: ignoredInputs,
                                behavior: behavior,
                                outputs: outputs,
                                stuckAt: 0,
                                cleanUp: !sampleRun,
                                filePrefix: tempDir
                            )

                        let sa1 =
                            try Simulator.pseudoRandomVerilogGeneration(
                                using: vector,
                                for: faultPoints,
                                in: file,
                                module: module,
                                with: cells,
                                ports: ports,
                                inputs: inputs,
                                ignoring: ignoredInputs,
                                behavior: behavior,
                                outputs: outputs,
                                stuckAt: 1,
                                cleanUp: !sampleRun,
                                filePrefix: tempDir
                            )

                        return Coverage(sa0: sa0, sa1: sa1)
                    } catch {
                        print("IO Error @ vector \(vector)")
                        return Coverage(sa0: [], sa1: [])

                    }
                }
                futureList.append(future)
                if sampleRun {
                    break
                }
            }

            for (i, future) in futureList.enumerated() {
                let coverLists = future.value
                for cover in coverLists.sa0 {
                    sa0Covered.insert(cover)
                }
                for cover in coverLists.sa1 {
                    sa1Covered.insert(cover)
                }
                coverageList.append(
                    TVCPair(
                        vector: testVectors[i],
                        coverage: coverLists
                    )
                )
            }

            coverage =
                Float(sa0Covered.count + sa1Covered.count) /
                Float(2 * faultPoints.count)
        
            totalTVAttempts += tvAttempts
            tvAttempts = increment
        }

        if coverage < minimumCoverage {
            print("Hit ceiling. Settling for current coverage.")
        }

        return (
            coverageList: coverageList,
            coverage: coverage
        )
    }

    enum Active {
        case low
        case high
    }

    static func simulate(
        verifying module: String,
        in file: String,
        with cells: String,
        ports: [String: Port],
        inputs: [Port],
        outputs: [Port],
        dffCount: Int,
        clock: String,
        reset: String,
        resetActive: Active = .low,
        testing: String
    ) throws -> Bool {
        let tempDir = "\(NSTemporaryDirectory())"

        let folderName = "\(tempDir)/thr\(Unmanaged.passUnretained(Thread.current).toOpaque())"
        let _ = "mkdir -p '\(folderName)'".sh()
        defer {
            let _ = "rm -rf '\(folderName)'".sh()
        }

        var portWires = ""
        var portHooks = ""
        for (rawName, port) in ports {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name) ;\n"
            portHooks += ".\(name) ( \(name) ) , "
        }

        var inputAssignment = ""
        for input in inputs {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"
            if input.name == reset {
                inputAssignment += "        \(name) = \( resetActive == .low ? 0 : 1 ) ;\n"
            } else {
                inputAssignment += "        \(name) = 0 ;\n"
            }
        }

        var serial = ""
        for _ in 0..<dffCount {
            serial += "\(Int.random(in: 0...1))"
        }

        let bench = """
        \(String.boilerplate)
        `include "\(cells)"
        `include "\(file)"

        module testbench;
        \(portWires)
            
            always #1 \(clock) = ~\(clock);

            \(module) uut(
                \(portHooks.dropLast(2))
            );

            wire[\(dffCount - 1):0] serializable =
                \(dffCount)'b\(serial);
            reg[\(dffCount - 1):0] serial;
            integer i;

            initial begin
        \(inputAssignment)
                #10;
                \(reset) = ~\(reset);
                \(testing) = 1;
                for (i = 0; i < \(dffCount); i = i + 1) begin
                    sin = serializable[i];
                    #2;
                end
                for (i = 0; i < \(dffCount); i = i + 1) begin
                    serial[i] = sout;
                    #2;
                end
                if (serial == serializable) begin
                    $display("SUCCESS_STRING");
                end
                $finish;
            end
        endmodule
        """

        let tbName = "\(folderName)/tb.sv"
        try File.open(tbName, mode: .write) {
            try $0.print(bench)
        }

        let aoutName = "\(folderName)/a.out"

        let iverilogResult =
            "iverilog -Ttyp -o \(aoutName) \(tbName) 2>&1 > /dev/null".sh()
        if iverilogResult != EX_OK {
            exit(Int32(iverilogResult))
        }

        let vvpTask = "vvp \(aoutName)".shOutput()

        if vvpTask.terminationStatus != EX_OK {
            throw "Failed to run vvp."
        }

        return vvpTask.output.contains("SUCCESS_STRING")
    }
}

class LFSR{
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
        32: [32, 30, 26, 25]    
    ];

    var seed: UInt
    var polynomialHex: UInt
    let nbits: UInt 
    
    init (nbits: UInt = 16){     
        let max: UInt = (1 << nbits) - 1  
        let polynomial =  LFSR.taps[nbits]!

        self.seed = UInt.random(in: 1...max)
        self.nbits = nbits
        self.polynomialHex = 0
        
        for tap in polynomial {
             self.polynomialHex = self.polynomialHex | (1 << (nbits-tap));
        }
    }

    static func parity (number: UInt) -> UInt {
        var parityVal: UInt = 0
        var numberTemp = number
        while(numberTemp != 0){
            parityVal ^= 1 
            numberTemp = numberTemp & (numberTemp - 1)
        }
        return parityVal
    }

    func next(outputBits: UInt) -> UInt{
        let feedbackBit: UInt = LFSR.parity(number: self.seed & self.polynomialHex)
        self.seed = (self.seed >> 1) | (feedbackBit << (self.nbits - 1))
        let mask = (1 << outputBits) - 1 
        return (self.seed & mask)
    }
}