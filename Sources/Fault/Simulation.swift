import Foundation
import Defile
import PythonKit

class Simulator {
    enum Behavior: Int {
        case holdHigh = 1
        case holdLow = 0
    }

    static func pseudoRandomVerilogGeneration(
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
        delayFault: Bool,
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
            faultForces += "        #1 ; \n"   
            faultForces += "        if (difference) $display(\"\(fault)\") ; \n"
            faultForces += "        #1 ; \n"
            faultForces += "        release uut.\(fault) ;\n"
            faultForces += "        #1 ; \n"

            if delayFault {
                faultForces += "        if(uut.\(fault) == \(stuckAt)) $display(\"v1: \(fault)\") ;\n"
            }
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
                                delayFault: false,
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
                                delayFault: false,
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
        sin: String,
        sout: String,
        resetActive: Active = .low,
        testing: String,
        clockDR: String,
        update: String,
        mode: String,
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
        let chainLength = internalCount + boundaryCount

        var serial = "0"
        for _ in 0..<chainLength {
            serial += "\(Int.random(in: 0...1))"
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
            wire[\(chainLength - 1):0] serializable =
                \(chainLength)'b\(serial);
            reg[\(chainLength - 1):0] serial;
            integer i;
            initial begin
                $dumpfile("dut.vcd"); // DEBUG
                $dumpvars(0, testbench);
        \(inputAssignment)
                #10;
                \(reset) = ~\(reset);
                \(testing) = 1;
                \(clockDR) = 1;
                \(update) = 1;
                \(mode) = 0;
                for (i = 0; i < \(chainLength); i = i + 1) begin
                    sin = serializable[i];
                    #2;
                end
                for (i = 0; i < \(chainLength); i = i + 1) begin
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

        let chainLength = internalCount + boundaryCount
        let ignored = [tck, trst, tdi, clock, tms, reset]
        let inputCellCount = inputs.count - ignored.count

        var inputInit = ""
        var inputAssignment = ""
        var sampleSerializable = ""
        for input in inputs {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"
            if input.name == reset {
                inputInit += "        \(name) = \( resetActive == .low ? 0 : 1 ) ;\n"
            } else if input.name == tms {
                inputInit += "        \(name) = 1 ;\n"
            }
            else {
                inputInit += "        \(name) = 0 ;\n"
                if (!ignored.contains(input.name)){
                    let bit = Int.random(in: 0...1)
                    inputAssignment += "        \(name) = \(bit) ;\n"
                    sampleSerializable += "\(bit)"
                }
            }
        }

        for _ in 0..<internalCount {
            sampleSerializable += "x"
        }

        var outputAssignment  = ""
        var count = 0
        for output in outputs {
            if (output.name != tdo){
                outputAssignment += "        serializable[\(boundaryCount - inputCellCount - count - 1)] = \(output.name) ; \n" 
                sampleSerializable += "x"
                count += 1
            }
        }

        var boundarySerial = ""
        for _ in 0..<chainLength {
            boundarySerial += "\(Int.random(in: 0...1))"
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

            wire[7:0] tmsPattern = 8'b 01100110;
            wire[3:0] extest = 4'b 0000;
            wire[3:0] samplePreload = 4'b 0001;
            wire[3:0] bypass = 4'b 1111;

            reg[\(chainLength - 1):0] serializable =
                \(chainLength)'b\(sampleSerializable);
            reg[\(chainLength - 1):0] serial;

            wire [\(chainLength - 1): 0] boundarySerial = 
                \(chainLength)'b\(boundarySerial);
            reg [\(chainLength - 1): 0] stores;

            initial begin
                $dumpfile("dut.vcd"); // DEBUG
                $dumpvars(0, testbench);
        \(inputInit)
                #2;
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
                for (i = 0; i < \(chainLength); i = i + 1) begin
                    \(tdi) = 0;
                    serial[i] = \(tdo); 
                    #2;
                end
                if(serial != serializable) begin
                    $error("EXECUTING_SAMPLE_INST_FAILED");
                    $finish;
                end
                exitDR();
                #2;
                // PRELOAD
                enterShiftDR();
                for (i = 0; i < \(chainLength); i = i + 1) begin
                    \(tdi) = boundarySerial[i];
                    #2;
                end
                for(i = 0; i< \(chainLength); i = i + 1) begin
                    stores[i] = \(tdo);
                    #2;
                end 
                if(stores != boundarySerial) begin
                    $error("EXECUTING_PRELOAD_INST_FAILED");
                    $finish;
                end
                exitDR();
                #2;
                /*
                    Test BYPASS Instruction 
                */
                #10;
                shiftIR(bypass);
                enterShiftDR();
                \(tdi) = 1;
                #6;
                for (i = 0; i < 10; i = i + 1) begin
                    if (\(tdo) != 1) begin
                        $error("ERROR_EXECUTING_BYPASS_INST");
                        $finish;
                    end
                    #2;
                end
                exitDR();

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

    static func simulate(
        verifying module: String,
        in file: String,
        with cells: String,
        ports: [String: Port],
        inputs: [Port],
        ignoring ignoredInputs: Set<String>,
        behavior: [Behavior],
        outputs: [Port],
        clock: String,
        reset: String,
        resetActive: Active = .low,
        tms: String,
        tdi: String,
        tck: String,
        tdo: String,
        trst: String,
        coverageList: [TVCPair], 
        output: String,
        internalCount: Int,
        using iverilogExecutable: String,
        with vvpExecutable: String
    ) throws -> Bool {
    
        var portWires = ""
        var portHooks = ""
        for (rawName, port) in ports {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            portWires += "    \(port.polarity == .input ? "reg" : "wire")[\(port.from):\(port.to)] \(name) ;\n"
            portHooks += ".\(name) ( \(name) ) , "
        }

        var inputAssignment = ""
        for (i, rawName) in ignoredInputs.enumerated() {
            let name = (rawName.hasPrefix("\\")) ? rawName : "\\\(rawName)"
            inputAssignment += "        \(name) = \(behavior[i].rawValue) ;\n"
        }

        let tvCount = coverageList.count
        let vectorLength = (tvCount != 0) ? coverageList[0].vector.count : 0
        let tapPorts = [tck, trst, tdi]

        var count = vectorLength - 1
        var vectorAssignment = ""
        for input in inputs {
            let name = (input.name.hasPrefix("\\")) ? input.name : "\\\(input.name)"
            if input.name == reset {
                inputAssignment += "        \(name) = \( resetActive == .low ? 0 : 1 ) ;\n"
            } else if input.name == tms {
                inputAssignment += "        \(name) = 1 ;\n"
            }
            else {
                inputAssignment += "        \(name) = 0 ;\n"
                if (input.name != clock && !tapPorts.contains(input.name)){
                    vectorAssignment += "        \(name) = vector[\(count)] ; \n" 
                    count -= 1
                }
            }
        }        

        var vectorInit = ""
        for (i, tvcPair) in coverageList.enumerated() {
            let output = tvcPair.goldenOutput
            var vector = ""
            for port in tvcPair.vector {
                vector += String(port, radix: 2) 
            }
            vectorInit += "        vectors[\(i)] = \(vectorLength)'b \(vector) ; \n"
            vectorInit += "        goldenOutput[\(i)] = \(output) ; \n"
        }

        let outputCount = coverageList[0].goldenOutput.count

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

            reg [\(outputCount - 1):0] scanInSerial;
            reg [\(vectorLength - 1):0] vectors [0:\(tvCount - 1)];
            reg [\(outputCount - 1):0] goldenOutput[0:\(tvCount - 1)];

            wire[7:0] tmsPattern = 8'b 01100110;
            wire[3:0] intest = 4'b 0100;

            initial begin
                $dumpfile("dut.vcd"); // DEBUG
                $dumpvars(0, testbench);
        \(inputAssignment)
        \(vectorInit)
                #10;
                \(resetToggler)
                \(trst) = 1;        
                #2;
                 
                for (i = 0 ; i < \(tvCount); i = i + 1) begin
                    test(vectors[i], goldenOutput[i]);
                end

                $display("SUCCESS_STRING");
                $finish;
            end

            task test;
                input [\(vectorLength - 1): 0] vector;
                input [\(outputCount - 1): 0] goldenOutput;
                begin
                    shiftIR(intest);
                    enterShiftDR();

                    for (i = 0; i < \(vectorLength); i = i + 1) begin
                        tdi = vector[i];
                        if(i == \(vectorLength - 1)) begin
                            \(tms) = 1; // Exit-DR
                        end
                        #2;
                    end
                    \(tms) = 1; // update-DR
                    #2;
                    \(tms) = 1; // select-DR
                    #2;
                    \(tms) = 0; // capture-DR
                    #2;
                    \(tms) = 0; // shift-DR
                    for (i = 0; i < \(internalCount); i = i + 1) begin
                        \(tdi) = 0;
                        scanInSerial[i] = \(tdo);
                        #2;
                    end
                    #20;
                    exitDR();

                    if(scanInSerial != goldenOutput) begin
                        $error("EXECUTING_SCANIN_INST_FAILED");
                        $finish;
                    end
                end
            endtask

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

        let tbName = "\(output)"

        try File.open(tbName, mode: .write) {
            try $0.print(bench)
        }

        let aoutName = "\(module).out"
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
