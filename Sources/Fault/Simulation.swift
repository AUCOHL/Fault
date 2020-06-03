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
        goldenOutput: Bool,
        filePrefix: String = ".",
        using iverilogExecutable: String,
        with vvpExecutable: String
    ) throws -> (faults: [String], goldenOutput: String) {
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
        let result = "mkdir -p \(folderName)".sh()

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

        var count = outputs.count - 1
        var outputComparison = ""
        var outputAssignment = ""
        for output in outputs {
            let name = (output.name.hasPrefix("\\")) ? output.name : "\\\(output.name)"
            outputComparison += " ( \(name) != \(name).gm ) || "
            outputAssignment += "   assign goldenOutput[\(count)] = \(name).gm ; \n"
            count -= 1
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
           
            \(goldenOutput ?
            "wire [\(outputs.count - 1):0] goldenOutput; \n \(outputAssignment)" : "")

            wire difference ;
            assign difference = (\(outputComparison));
            
            integer counter;

            initial begin
        \(inputAssignment)
        \(faultForces)
        \(goldenOutput ? "        $displayb(\"%b\", goldenOutput);": "" )
                $finish;
            end

        endmodule
        """;

        let tbName = "\(folderName)/tb.sv"
        try File.open(tbName, mode: .write) {
            try $0.print(bench)
        }

        let aoutName = "\(folderName)/a.out"
        let intermediate = "\(folderName)/intermediate"
        let env = ProcessInfo.processInfo.environment
        let iverilogExecutable = env["FAULT_IVERILOG"] ?? "iverilog"
        let vvpExecutable = env["FAULT_VVP"] ?? "vvp"

        let iverilogResult =
            "'\(iverilogExecutable)' -B '\(iverilogBase)' -Ttyp -o \(aoutName) \(tbName) 2>&1 > /dev/null".sh()
        if iverilogResult != EX_OK {
            exit(Int32(iverilogResult))
        }

        let vvpTask = "'\(vvpExecutable)' \(aoutName) > \(intermediate)".sh()
        if vvpTask != EX_OK {
            exit(vvpTask)
        }

        let output = File.read(intermediate)!

        defer {
            if cleanUp {
                let _ = "rm -rf \(folderName)".sh()
            }
        }

        var faults = output.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
    
        let gmOutput = goldenOutput ? faults.removeLast() : ""
        return (faults: faults, goldenOutput: gmOutput)
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
        randomGenerator: RNG,
        TVSet: [TestVector],
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
        var tvAttempts = (initialVectorCount < ceiling) ? initialVectorCount : ceiling
        
        let simulateOnly = (TVSet.count != 0)
        let rng: URNG = RNGFactory.shared().getRNG(type: randomGenerator)
        
        while coverage < minimumCoverage && totalTVAttempts < ceiling {
            if totalTVAttempts > 0 {
                print("Minimum coverage not met (\(coverage * 100)%/\(minimumCoverage * 100)%,) incrementing to \(totalTVAttempts + tvAttempts)…")
            }

            var futureList: [Future] = []
            var testVectors: [TestVector] = []
            for index in 0..<tvAttempts {
                var testVector: TestVector = []
                if (simulateOnly){
                    testVector = TVSet[totalTVAttempts + index]
                } else {
                    for input in inputs {
                        testVector.append(rng.generate(bits: input.width))
                    }
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
                        let (sa0, output) =
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
                                goldenOutput: true,
                                filePrefix: tempDir,
                                using: iverilogExecutable,
                                with: vvpExecutable
                            )

                        let (sa1, _) =
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
                                goldenOutput: false,
                                filePrefix: tempDir,
                                using: iverilogExecutable,
                                with: vvpExecutable
                            )

                        return (Covers: Coverage(sa0: sa0, sa1: sa1) , Output: output)
                    } catch {
                        print("IO Error @ vector \(vector)")
                        return (Covers: Coverage(sa0: [], sa1: []) , Output: "")

                    }
                }
                futureList.append(future)
                if sampleRun {
                    break
                }
            }

            for (i, future) in futureList.enumerated() {
                let (coverLists, output) = future.value as! (Coverage, String)
                for cover in coverLists.sa0 {
                    sa0Covered.insert(cover)
                }
                for cover in coverLists.sa1 {
                    sa1Covered.insert(cover)
                }
                coverageList.append(
                    TVCPair(
                        vector: testVectors[i],
                        coverage: coverLists,
                        goldenOutput: output
                    )
                )
            }

            coverage =
                Float(sa0Covered.count + sa1Covered.count) /
                Float(2 * faultPoints.count)
           
            totalTVAttempts += tvAttempts
            let remainingTV = ceiling - totalTVAttempts
            tvAttempts = (remainingTV < increment) ? remainingTV : increment
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
        boundaryCount: Int,
        internalCount: Int,
        clock: String,
        reset: String,
        tck: String,
        sinInternal: String,
        sinBoundary: String,
        soutInternal: String,
        soutBoundary: String,
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

        var boundarySerial = "0"
        for _ in 0..<boundaryCount {
            boundarySerial += "\(Int.random(in: 0...1))"
        }

        var internalSerial = "0"
        for _ in 0..<internalCount {
            internalSerial += "\(Int.random(in: 0...1))"
        }
        
        var clockCreator = ""
        if !clock.isEmpty {
            clockCreator = "always #1 \(clock) = ~\(clock);"
        }

        let bench = """
        \(String.boilerplate)
        `include "\(cells)"
        `include "\(file)"

        module testbench;
        \(portWires)

            \(clockCreator)
            always #1 \(tck) = ~\(tck);

            \(module) uut(
                \(portHooks.dropLast(2))
            );

            wire[\(boundaryCount - 1):0] boundarySerializable =
                \(boundaryCount)'b\(boundarySerial);
            reg[\(boundaryCount - 1):0] boundarySerial;
            
            wire[\(internalCount == 0 ? 1 : internalCount  - 1):0] internalSerializable =
                \(internalCount == 0 ? 1 : internalCount)'b\(internalSerial);
            reg[\(internalCount - 1):0] internalSerial;

            integer i;

            initial begin
        \(inputAssignment)
                #10;
                \(reset) = ~\(reset);
                \(testing) = 1;

                for (i = 0; i < \(boundaryCount); i = i + 1) begin
                    \(sinBoundary) = boundarySerializable[i];
                    #2;
                end
                #4;
                for (i = 0; i < \(boundaryCount); i = i + 1) begin
                    boundarySerial[i] = \(soutBoundary);
                    #2;
                end

                if (boundarySerial != boundarySerializable) begin
                    $error("FAILED_SERIALIZING_THROUGH_BOUNDARY_CHAIN");
                    $finish;
                end

                for (i = 0; i < \(internalCount); i = i + 1) begin
                    \(sinInternal) = internalSerializable[i];
                    #2;
                end
                for (i = 0; i < \(internalCount); i = i + 1) begin
                    internalSerial[i] = \(soutInternal);
                    #2;
                end

                if (internalSerial != internalSerializable) begin
                    $error("FAILED_SERIALIZING_THROUGH_INTERNAL_CHAIN");
                    $finish;
                end
                
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
                    let assignStatement =
                        "        stores[\(count)] = uut.__dut__.\\__BoundaryScanRegister_input_\(count)__.store "
                    storesAssignment += "\(assignStatement);\n"
                    count = count + 1
                }
            }
        }
       
        var outputAssignment  = ""
        for output in outputs {
            if (output.name != tdo){
                let assignStatement = 
                    "        stores[\(count)] = uut.__dut__.\\__BoundaryScanRegister_output_\(count)__.store "
                storesAssignment += "\(assignStatement);\n"
                outputAssignment += "        serializable[\(boundaryCount - count - 1)] = \(output.name) ; \n" 
                serial += "0"
                count = count + 1
            }
        }

        var boundarySerial = ""
        for _ in 0..<boundaryCount {
            boundarySerial += "\(Int.random(in: 0...1))"
        }

        var scanInSerial = ""
        for _ in 0..<internalCount {
            scanInSerial += "\(Int.random(in: 0...1))"
        }

        var clockCreator = ""
        if !clock.isEmpty {
            clockCreator = "always #1 \(clock) = ~\(clock);"
        }
        var resetToggler = ""
        if !reset.isEmpty {
            resetToggler = "\(reset) = ~\(reset);"
        }

        let bench = """
        \(String.boilerplate)
        `include "\(cells)"
        `include "\(file)"

        module testbench;
        \(portWires)
            
            \(clockCreator)
            always #1 \(tck) = ~\(tck);

            \(module) uut(
                \(portHooks.dropLast(2))
            );

            integer i;
            reg [\(boundaryCount - 1): 0] stores;
            reg[7:0] tmsPattern = 8'b 01100110;

            wire[3:0] extest = 4'b 0000;
            wire[3:0] samplePreload = 4'b 0001;
            wire[3:0] bypass = 4'b 1111;
            wire[3:0] scanIn = 4'b 0100;

            reg[\(boundaryCount - 1):0] serializable =
                \(boundaryCount)'b\(serial);
            wire [\(boundaryCount - 1): 0] boundarySerial = 
                \(boundaryCount)'b\(boundarySerial);
           
            reg[\(boundaryCount - 1):0] serial;
            
            wire [\(internalCount == 0 ? 1 : internalCount - 1): 0] scanInSerializable = 
                \(internalCount == 0 ? 1 : internalCount)'b\(scanInSerial.isEmpty ? "0" : scanInSerial);
            reg[\(internalCount - 1):0] scanInSerial;

            initial begin
                $dumpfile("dut.vcd"); // DEBUG
                $dumpvars(0, testbench);
        \(inputInit)
                #10;
                \(resetToggler)
                \(trst) = 1;        
                #2;
                /*
                    Test Sample/Preload Instruction
                */
                shiftIR(samplePreload);

                // SAMPLE
                \(tms) = 1;     // select-DR 
                #2;
                \(tms) = 0;     // capture-DR 
        \(inputAssignment)
                #2;
                \(tms) = 0;     // shift-DR 
                #2;
        \(outputAssignment)
                #2;
                for (i = 0; i < \(boundaryCount); i = i + 1) begin
                    \(tms) = 0;
                    serial[i] = \(tdo); 
                    #2;
                end
                if(serial != serializable) begin
                    $error("EXECUTING_SAMPLE_INST_FAILED");
                    $finish;
                end
                #100;
                exitDR();

                // PRELOAD
                enterShiftDR();
                for (i = 0; i < \(boundaryCount); i = i + 1) begin
                    \(tdi) = boundarySerial[i];
                    if(i == \(boundaryCount - 1)) begin
                        exitDR();
                    end
                    #2;
                end
        \(storesAssignment)
                for(i = 0; i< \(boundaryCount); i = i + 1) begin
                    if(stores[i] != boundarySerial[i + \(boundaryCount - 1)]) begin
                        $error("EXECUTING_PRELOAD_INST_FAILED");
                        $finish;
                    end
                end 
                /*
                    Test SCAN IN Instruction
                */
                shiftIR(scanIn);
                enterShiftDR();

                for (i = 0; i < \(internalCount); i = i + 1) begin
                    \(tdi) = scanInSerializable[i];
                    #2;
                end

                for (i = 0; i < \(internalCount); i = i + 1) begin
                    scanInSerial[i] = \(tdo);
                    if(i == \(internalCount - 1)) begin
                        exitDR();
                    end
                    #2;
                end
                if(scanInSerial != scanInSerializable) begin
                    $error("EXECUTING_SCANIN_INST_FAILED");
                    $finish;
                end
                /*
                    Test BYPASS Instruction 
                */
                shiftIR(bypass);
                enterShiftDR();

                for (i = 0; i < 10; i = i + 1) begin
                    \(tdi) = 1;
                    #2;
                    if (\(tdo) != 1) begin
                        $error("ERROR_EXECUTING_BYPASS_INST");
                    end
                    if(i == 9) begin
                        exitDR();
                    end
                end

                $display("SUCCESS_STRING");
                $finish;
            end

            task shiftIR;
                input[3:0] instruction;
                integer i;
                begin
                    for (i = 0; i< 5; i = i + 1) begin
                        \(tms) = tmsPattern[i];
                        #2;
                    end

                    // At shift-IR: shift new instruction on tdi line
                    for (i = 0; i < 4; i = i + 1) begin
                        tdi = instruction[i];
                        if(i == 3) begin
                            \(tms) = tmsPattern[5];     // exit-ir
                        end
                        #2;
                    end

                    \(tms) = tmsPattern[6];     // update-ir 
                    #2;
                    \(tms) = tmsPattern[7];     // run test-idle
                    #6;
                end
            endtask

            task enterShiftDR;
                begin
                    \(tms) = 1;     // select DR
                    #2;
                    \(tms) = 0;     // capture DR -- shift DR
                    #4;
                end
            endtask

            task exitDR;
                begin
                    \(tms) = 1;     // Exit DR -- update DR
                    #4;
                    \(tms) = 0;     // Run test-idle
                    #2;
                end
            endtask
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
