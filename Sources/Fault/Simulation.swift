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
        filePrefix: String = ".",
        using iverilogExecutable: String,
        with vvpExecutable: String
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
        
        let env = ProcessInfo.processInfo.environment
        let iverilogExecutable = env["FAULT_IVERILOG"] ?? "iverilog"
        let vvpExecutable = env["FAULT_VVP"] ?? "vvp"

        let iverilogResult =
            "'\(iverilogExecutable)' -B '\(iverilogBase)' -Ttyp -o \(aoutName) \(tbName) 2>&1 > /dev/null".sh()
        if iverilogResult != EX_OK {
            exit(Int32(iverilogResult))
        }

        let vvpTask = "'\(vvpExecutable)' \(aoutName)".shOutput()

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
        randomGenerator: RandomGenerator,
        sampleRun: Bool,
        using iverilogExecutable: String,
        with vvpExecutable: String
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
        
        let rng: URNG = RandGenFactory.shared().getRandGen(type:randomGenerator) // LFSR(nbits: 64)

        while coverage < minimumCoverage && totalTVAttempts < ceiling {
            if totalTVAttempts > 0 {
                print("Minimum coverage not met (\(coverage * 100)%/\(minimumCoverage * 100)%,) incrementing to \(totalTVAttempts + tvAttempts)…")
            }

            var futureList: [Future] = []
            var testVectors: [TestVector] = []
            

            for _ in 0..<tvAttempts {
                var testVector: TestVector = []
                for input in inputs {
                    let max: UInt = (1 << UInt(input.width)) - 1
                    testVector.append(
                       rng.generate(0...max)
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
                let future = Future {
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
                                filePrefix: tempDir,
                                using: iverilogExecutable,
                                with: vvpExecutable
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
                                filePrefix: tempDir,
                                using: iverilogExecutable,
                                with: vvpExecutable
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
                let coverLists = future.value as! Coverage
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
        testing: String,
        using iverilogExecutable: String,
        with vvpExecutable: String
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
                #2;
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
            "'\(iverilogExecutable)' -B '\(iverilogBase)' -Ttyp -o \(aoutName) \(tbName) 2>&1 > /dev/null".shOutput()
        
        
        if iverilogResult.terminationStatus != EX_OK {
            fputs("An iverilog error has occurred: \n", stderr)
            fputs(iverilogResult.output, stderr)
            exit(Int32(iverilogResult.terminationStatus))
        }
        let vvpTask = "'\(vvpExecutable)' \(aoutName)".shOutput()

        if vvpTask.terminationStatus != EX_OK {
            throw "Failed to run vvp."
        }

        return vvpTask.output.contains("SUCCESS_STRING")
    }

    static func simulate(
        verifying module: String,
        in file: String,
        with cells: String,
        ports: [String: Port],
        inputs: [Port],
        outputs: [Port],
        boundaryCount: Int,
        internalCount: Int,
        clock: String,
        reset: String,
        resetActive: Active = .low,
        tms: String,
        tdi: String,
        tck: String,
        tdo: String,
        trst: String,
        using iverilogExecutable: String,
        with vvpExecutable: String
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

        var inputInit = ""
        var inputAssignment = ""
        var serial = ""
        var storesAssignment = ""

        var count = 0
        for input in inputs {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"
            if input.name == reset {
                inputInit += "        \(name) = \( resetActive == .low ? 0 : 1 ) ;\n"
            } else if input.name == tms {
                inputInit += "        \(name) = 1 ;\n"
            }
            else {
                inputInit += "        \(name) = 0 ;\n"
                if (input.name != tck && input.name != clock && input.name != trst && input.name != tdi){
                    let bit = Int.random(in: 0...1)
                    inputAssignment += "        \(name) = \(bit) ;\n"
                    serial += "\(bit)"
                    let assignStatement = "        stores[\(count)] = uut.__dut__.\\__BoundaryScanRegister_input_\(count)__.store "
                    storesAssignment += "\(assignStatement);\n"
                    count = count + 1
                }
            }
        }

        let inputBSCount = count
        
        for output in outputs {
            if (output.name != tdo){
                let assignStatement = "stores[\(count)] = uut.__dut__.\\__BoundaryScanRegister_output_\(count)__.store "
                storesAssignment += "\(assignStatement);\n"
                count = count + 1
            }
        }
        
        let outputBSCount = count - inputBSCount
        let dffCount = internalCount + boundaryCount - 1

        var tdiSerial = ""
        for _ in 0..<dffCount {
            tdiSerial += "\(Int.random(in: 0...1))"
        }
        let bench = """
        \(String.boilerplate)
        `include "\(cells)"
        `include "\(file)"

        module testbench;
        \(portWires)
            
            always #1 \(clock) = ~\(clock);
            always #1 \(tck) = ~\(tck);

            \(module) uut(
                \(portHooks.dropLast(2))
            );

            integer i;
            reg [\(boundaryCount - 1): 0] stores;

            wire[3:0] extest = 4'b 0000;
            wire[3:0] samplePreload = 4'b 0001;
            wire[3:0] idcode = 4'b 0010;
            wire[3:0] bypass = 4'b 1111;
            
            wire[3:0] ir_reg = 4'b 0101;
            wire[\(boundaryCount - 1):0] serializable =
                \(boundaryCount)'b\(serial);
            wire [\(dffCount - 1): 0] tdiSerial = 
                \(dffCount)'b\(tdiSerial);
            reg[\(dffCount - 1):0] serial;

            initial begin
                $dumpfile("dut.vcd"); // DEBUG
                $dumpvars(0, testbench);
        \(inputInit)
                #10;
                \(reset) = ~\(reset);
                \(trst) = 1;        
                #2;
                /*
                    Test Sample/Preload Instruction
                */
                \(tms) = 1;     // test logic reset state
                #10;
                \(tms) = 0;     // run-test idle state
                #2;
                \(tms) = 1;     // select-DR state
                #2;
                \(tms) = 1;     // select-IR state
                #2;
                \(tms) = 0;     // capture IR
                #2;
                \(tms) = 0;     // Shift IR state
                #2

                // shift new instruction on tdi line
                for (i = 0; i < 4; i = i + 1) begin
                    \(tdi) = samplePreload[i];
                    if(i == 3) begin
                        \(tms) = 1;     // exit-ir
                    end
                    #2;
                end
                \(tms) = 1;     // update-ir 
                #2;
                \(tms) = 0;     // run test-idle
                #6;

                // SAMPLE
                \(tms) = 1;     // select-DR 
                #2;
                \(tms) = 0;     // capture-DR 
        \(inputAssignment)
                #2;
                \(tms) = 0;     // shift-DR 
                #6;
                for (i = 0; i < \(dffCount); i = i + 1) begin
                    \(tms) = 0;
                    serial[i] = \(tdo); 
                    #2;
                end
                if(serial[\(boundaryCount + 1):\(internalCount - 1)] != serializable) begin
                    $error("EXECUTING_SAMPLE_INST_FAILED");
                    $finish;
                end
                #100;
                \(tms) = 1;     // Exit DR
                #2;
                \(tms) = 1;     // update DR
                #2;
                \(tms) = 0;     // Run test-idle
                #2;

                // PRELOAD
                \(tms) = 1;     // select DR
                #2;
                \(tms) = 0;     // capture DR
                #2;
                \(tms) = 0;     // shift DR
                #2;
                for (i = 0; i < \(dffCount); i = i + 1) begin
                    \(tdi) = tdiSerial[i];
                    if(i == \(dffCount - 1))
                        \(tms) = 1;     // exit-dr
                    #2;
                end
                \(tms) = 1;     // update DR
                #2;
                \(tms) = 0;     // run-test idle
                #2;
        \(storesAssignment)
                for(i = 0; i< \(inputBSCount); i = i + 1) begin
                    if(stores[i] != tdiSerial[i + \(dffCount - 1)]) begin
                        $error("EXECUTING_PRELOAD_INST_FAILED");
                        $finish;
                    end
                end 

                for(i = 0; i< \(outputBSCount); i = i + 1) begin
                    if(stores[\(boundaryCount) - i] != tdiSerial[i]) begin
                        $error("EXECUTING_PRELOAD_INST_FAILED");
                        $finish;
                    end
                end

                /*
                    Test EXTEST Instruction
                */
                
                #100;
                $display("SUCCESS_STRING");
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
            "'\(iverilogExecutable)' -B '\(iverilogBase)' -Ttyp -o \(aoutName) \(tbName) 2>&1 > /dev/null".shOutput()
        

        if iverilogResult.terminationStatus != EX_OK {
            fputs("An iverilog error has occurred: \n", stderr)
            fputs(iverilogResult.output, stderr)
            exit(Int32(iverilogResult.terminationStatus))
        }
        let vvpTask = "'\(vvpExecutable)' \(aoutName)".shOutput()

        if vvpTask.terminationStatus != EX_OK {
            throw "Failed to run vvp."
        }

        return vvpTask.output.contains("SUCCESS_STRING")
    }
}
